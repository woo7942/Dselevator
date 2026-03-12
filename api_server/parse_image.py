#!/usr/bin/env python3
"""
검사 지적사항 캡처 이미지 파서
Tesseract OCR로 이미지에서 텍스트 추출 후 구조화
"""
import sys
import json
import re
import os
from pathlib import Path

try:
    import pytesseract
    from PIL import Image, ImageFilter, ImageEnhance
    import cv2
    import numpy as np
except ImportError as e:
    print(json.dumps({"success": False, "error": f"패키지 없음: {e}"}))
    sys.exit(1)


def preprocess_image(img_path: str) -> np.ndarray:
    """OCR 정확도 향상을 위한 이미지 전처리"""
    img = cv2.imread(img_path)
    if img is None:
        raise ValueError(f"이미지를 읽을 수 없습니다: {img_path}")

    # 그레이스케일 변환
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 이미지 크기 조정 (너무 작으면 확대)
    h, w = gray.shape
    if w < 1000:
        scale = 1000 / w
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    # 노이즈 제거
    gray = cv2.fastNlMeansDenoising(gray, h=10)

    # 이진화 (적응형 임계값)
    binary = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 11, 2
    )

    return binary


def extract_text_from_image(img_path: str) -> str:
    """이미지에서 텍스트 추출"""
    # 전처리
    preprocessed = preprocess_image(img_path)

    # 임시 파일로 저장
    tmp_path = img_path + "_preprocessed.png"
    cv2.imwrite(tmp_path, preprocessed)

    try:
        # Tesseract OCR (한국어 + 영어)
        custom_config = r'--oem 3 --psm 6 -l kor+eng'
        text = pytesseract.image_to_string(
            Image.open(tmp_path),
            config=custom_config
        )
        return text
    finally:
        try:
            os.remove(tmp_path)
        except:
            pass


def guess_severity(text: str) -> str:
    """텍스트에서 심각도 추정"""
    text_lower = text.lower()
    if any(k in text for k in ['중결함', '重結缺', '불량', '고장', '누수', '파손', '불가', '결함']):
        return '중결함'
    if any(k in text for k in ['경결함', '경미', '마모', '노후']):
        return '경결함'
    if any(k in text for k in ['권고', '권장', '주의', '확인 필요']):
        return '권고사항'
    return '경결함'


def parse_inspection_text(raw_text: str) -> dict:
    """OCR로 추출된 텍스트를 구조화된 지적사항으로 파싱"""
    lines = [l.strip() for l in raw_text.split('\n') if l.strip()]

    # 날짜 추출
    detected_date = None
    date_pattern = re.compile(r'(\d{4})[.\-년\s]+(\d{1,2})[.\-월\s]+(\d{1,2})')
    for line in lines:
        m = date_pattern.search(line)
        if m:
            y, mo, d = m.group(1), m.group(2).zfill(2), m.group(3).zfill(2)
            if int(y) >= 2020:
                detected_date = f"{y}-{mo}-{d}"
                break

    # 현장명 추출 (건물명, 현장 등 키워드 근처)
    detected_site = None
    site_keywords = ['건물명', '현장명', '건물', '현장', '사업장']
    for i, line in enumerate(lines):
        for kw in site_keywords:
            if kw in line:
                # 같은 줄이나 다음 줄에서 현장명 추출
                rest = line.split(kw)[-1].strip(' :：')
                if rest and len(rest) > 1:
                    detected_site = rest.split()[0] if rest.split() else rest
                    break
                elif i + 1 < len(lines):
                    candidate = lines[i + 1].strip()
                    if candidate and len(candidate) < 30:
                        detected_site = candidate
                        break
        if detected_site:
            break

    # 지적사항 목록 추출
    issues = []
    
    # 호기 패턴 (1호기, 2호기, ES-1, EL-1 등)
    hogi_pattern = re.compile(r'^(\d+호기|[A-Z]{1,3}-?\d+|엘리베이터\s*\d+)', re.IGNORECASE)
    
    # 번호 패턴 (①②③ 또는 1. 2. 3. 또는 - 또는 ▶)
    issue_start_pattern = re.compile(
        r'^[①②③④⑤⑥⑦⑧⑨⑩\u2460-\u2473]'  # 원 숫자
        r'|^\d+\.'                              # 숫자+점
        r'|^[-•▶▷·]\s'                          # 불릿 기호
        r'|^\[\d+\]'                            # [숫자]
        r'|^\d+\)'                              # 숫자)
    )
    
    # 심각도 패턴
    severity_pattern = re.compile(r'(중결함|경결함|권고사항|권고)', re.IGNORECASE)

    current_hogi = '(호기 미지정)'
    current_issues = []
    
    def flush_issues():
        for desc in current_issues:
            if desc:
                severity = guess_severity(desc)
                # 심각도가 텍스트에 명시된 경우
                sm = severity_pattern.search(desc)
                if sm:
                    severity = sm.group(1)
                    if severity == '권고':
                        severity = '권고사항'
                    # 심각도 텍스트를 설명에서 제거
                    desc = severity_pattern.sub('', desc).strip(' /:[]')

                if len(desc) > 2:
                    issues.append({
                        'elevatorLabel': current_hogi,
                        'description': desc,
                        'severity': severity,
                        'issueNo': len([x for x in issues if x['elevatorLabel'] == current_hogi]) + 1,
                        'include': True,
                        'checkCode': '',
                    })
    
    for line in lines:
        # 호기 라벨 감지
        hm = hogi_pattern.match(line)
        if hm:
            flush_issues()
            current_issues = []
            current_hogi = hm.group(0).strip()
            continue
        
        # 지적사항 항목 감지
        if issue_start_pattern.match(line):
            # 기호/번호 제거하고 내용만
            cleaned = re.sub(
                r'^[①②③④⑤⑥⑦⑧⑨⑩\u2460-\u2473\-•▶▷·]\s*'
                r'|\^\d+\.\s*|\^\d+\)\s*|\^\[\d+\]\s*',
                '', line
            ).strip()
            cleaned = re.sub(r'^\d+[.)]\s*', '', cleaned).strip()
            if cleaned:
                current_issues.append(cleaned)
        elif current_issues and line and len(line) > 3:
            # 이전 항목의 연속 텍스트
            current_issues[-1] = current_issues[-1] + ' ' + line

    flush_issues()

    # 결과가 없으면 전체 텍스트를 단순 라인별로 파싱 시도
    if not issues:
        for line in lines:
            if len(line) > 5 and not any(kw in line for kw in ['검사일', '현장', '건물', '주소', '성명']):
                issues.append({
                    'elevatorLabel': '(호기 미지정)',
                    'description': line,
                    'severity': guess_severity(line),
                    'issueNo': len(issues) + 1,
                    'include': True,
                    'checkCode': '',
                })

    return {
        'success': True,
        'detectedDate': detected_date,
        'detectedSite': detected_site,
        'parsedIssues': issues,
        'totalCount': len(issues),
        'rawText': raw_text[:2000],
    }


def parse_inspection_image(image_path: str) -> dict:
    """메인 파싱 함수"""
    try:
        raw_text = extract_text_from_image(image_path)
        if not raw_text.strip():
            return {
                'success': False,
                'error': '이미지에서 텍스트를 추출하지 못했습니다. 더 선명한 이미지를 사용해주세요.',
                'rawText': '',
                'parsedIssues': [],
                'totalCount': 0,
            }
        result = parse_inspection_text(raw_text)
        result['filename'] = os.path.basename(image_path)
        return result
    except Exception as e:
        return {
            'success': False,
            'error': str(e),
            'parsedIssues': [],
            'totalCount': 0,
        }


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({'success': False, 'error': '이미지 경로 인수가 없습니다'}))
        sys.exit(1)
    result = parse_inspection_image(sys.argv[1])
    print(json.dumps(result, ensure_ascii=False))
