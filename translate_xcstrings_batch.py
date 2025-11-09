#!/usr/bin/env python3
"""
Xcode String Catalog (.xcstrings) Batch Translation Tool
Supports Japanese to multiple languages with rate limiting and error handling
"""

import os
import json
import time
from datetime import datetime
from typing import Dict, List, Tuple

try:
    from googletrans import Translator
    TRANSLATOR_AVAILABLE = True
except ImportError:
    TRANSLATOR_AVAILABLE = False
    print("⚠️  googletrans not installed. Run: pip3 install googletrans==4.0.0rc1")

# Configuration
SUPPORTED_LANGUAGES = {
    'ja': 'Japanese (日本語)',
    'en': 'English',
    'zh-Hans': 'Simplified Chinese (简体中文)',
    'zh-Hant': 'Traditional Chinese (繁體中文)',
}

GOOGLE_TRANSLATE_MAPPING = {
    'ja': 'ja',
    'en': 'en',
    'zh-Hans': 'zh-CN',
    'zh-Hant': 'zh-TW',
}

# Rate limiting configuration
BATCH_SIZE = 10  # Translate 10 strings at a time
BATCH_DELAY = 2  # Wait 2 seconds between batches
REQUEST_DELAY = 0.5  # Wait 0.5 seconds between individual translations

class TranslationStats:
    def __init__(self):
        self.total = 0
        self.translated = 0
        self.skipped = 0
        self.failed = 0
        self.start_time = None
        self.end_time = None
    
    def print_summary(self):
        duration = (self.end_time - self.start_time) if self.end_time and self.start_time else 0
        print("\n" + "="*80)
        print("📊 翻訳結果サマリー")
        print("="*80)
        print(f"総文字列数:     {self.total}")
        print(f"翻訳完了:       {self.translated} ✅")
        print(f"スキップ:       {self.skipped} ⏭️")
        print(f"失敗:           {self.failed} ❌")
        print(f"処理時間:       {duration:.1f} 秒")
        print("="*80)

def translate_string(text: str, target_lang: str, translator: Translator, retry_count: int = 3) -> Tuple[str, bool]:
    """
    Translate a string with retry logic
    Returns: (translated_text, success)
    """
    dest_lang = GOOGLE_TRANSLATE_MAPPING.get(target_lang, target_lang)
    
    for attempt in range(retry_count):
        try:
            # Detect source language
            detected = translator.detect(text)
            if detected.lang == dest_lang:
                return text, True
            
            # Translate
            result = translator.translate(text, dest=dest_lang)
            return result.text, True
            
        except Exception as e:
            if attempt < retry_count - 1:
                wait_time = (attempt + 1) * 2  # Exponential backoff
                print(f"  ⚠️  翻訳失敗 (試行 {attempt + 1}/{retry_count}): {str(e)}")
                print(f"  ⏳ {wait_time}秒待機...")
                time.sleep(wait_time)
            else:
                print(f"  ❌ 翻訳失敗 (最終): {str(e)}")
                return text, False
    
    return text, False

def load_xcstrings(file_path: str) -> Dict:
    """Load .xcstrings file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_xcstrings(file_path: str, data: Dict):
    """Save .xcstrings file"""
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def translate_xcstrings(file_path: str, target_languages: List[str], force: bool = False):
    """
    Translate .xcstrings file to target languages
    
    Args:
        file_path: Path to .xcstrings file
        target_languages: List of target language codes (e.g., ['en', 'zh-Hans'])
        force: If True, re-translate even if translation exists
    """
    if not TRANSLATOR_AVAILABLE:
        print("❌ googletrans is not available. Cannot proceed.")
        return
    
    print(f"\n📖 ファイルを読み込み中: {file_path}")
    data = load_xcstrings(file_path)
    
    source_lang = data.get('sourceLanguage', 'ja')
    all_keys = list(data['strings'].keys())
    
    print(f"📝 ソース言語: {source_lang}")
    print(f"🎯 ターゲット言語: {', '.join([SUPPORTED_LANGUAGES.get(lang, lang) for lang in target_languages])}")
    print(f"📊 総文字列数: {len(all_keys)}")
    
    translator = Translator()
    stats = TranslationStats()
    stats.total = len(all_keys)
    stats.start_time = time.time()
    
    # Process each target language
    for target_lang in target_languages:
        print(f"\n{'='*80}")
        print(f"🌐 {SUPPORTED_LANGUAGES.get(target_lang, target_lang)} への翻訳を開始")
        print(f"{'='*80}\n")
        
        translated_count = 0
        
        # Process in batches
        for batch_start in range(0, len(all_keys), BATCH_SIZE):
            batch_end = min(batch_start + BATCH_SIZE, len(all_keys))
            batch_keys = all_keys[batch_start:batch_end]
            
            print(f"📦 バッチ処理中 ({batch_start + 1}-{batch_end}/{len(all_keys)})...")
            
            for i, key in enumerate(batch_keys, start=batch_start + 1):
                now = datetime.now().strftime("%H:%M:%S")
                print(f"[{now}] {i}/{len(all_keys)}: {key[:60]}{'...' if len(key) > 60 else ''}")
                
                strings = data['strings'][key]
                
                # Initialize if needed
                if 'localizations' not in strings:
                    strings['localizations'] = {}
                
                localizations = strings['localizations']
                
                # Check if translation exists
                if target_lang in localizations and not force:
                    print(f"  ⏭️  既に翻訳済み")
                    stats.skipped += 1
                    continue
                
                # Get source text (always the key for Japanese)
                source_text = key
                
                # Translate
                translated_text, success = translate_string(source_text, target_lang, translator)
                
                if success:
                    localizations[target_lang] = {
                        "stringUnit": {
                            "state": "translated",
                            "value": translated_text
                        }
                    }
                    print(f"  ✅ {target_lang}: {translated_text[:60]}{'...' if len(translated_text) > 60 else ''}")
                    stats.translated += 1
                    translated_count += 1
                else:
                    stats.failed += 1
                
                # Save after each translation
                data['strings'][key]['localizations'] = localizations
                save_xcstrings(file_path, data)
                
                # Rate limiting
                time.sleep(REQUEST_DELAY)
            
            # Batch delay (except for last batch)
            if batch_end < len(all_keys):
                print(f"⏳ バッチ間待機 ({BATCH_DELAY}秒)...\n")
                time.sleep(BATCH_DELAY)
        
        print(f"\n✅ {SUPPORTED_LANGUAGES.get(target_lang, target_lang)}: {translated_count} 個の文字列を翻訳しました")
    
    stats.end_time = time.time()
    stats.print_summary()

def main():
    print("="*80)
    print("🌐 Xcode String Catalog 一括翻訳ツール")
    print("="*80)
    print("\n対応言語:")
    for code, name in SUPPORTED_LANGUAGES.items():
        print(f"  - {code}: {name}")
    
    # Get file path
    file_path = input("\n📂 .xcstrings ファイルのパス: ").strip(' "\'')
    
    if not os.path.exists(file_path):
        print(f"❌ ファイルが見つかりません: {file_path}")
        return
    
    # Get target languages
    print("\n翻訳したい言語コードを入力してください（カンマ区切り）")
    print("例: en,zh-Hans,zh-Hant")
    target_langs_input = input("言語コード: ").strip()
    target_langs = [lang.strip() for lang in target_langs_input.split(',')]
    
    # Validate languages
    invalid_langs = [lang for lang in target_langs if lang not in SUPPORTED_LANGUAGES]
    if invalid_langs:
        print(f"❌ 無効な言語コード: {', '.join(invalid_langs)}")
        return
    
    # Confirm
    print("\n" + "="*80)
    print("確認:")
    print(f"  ファイル: {file_path}")
    print(f"  翻訳先: {', '.join([SUPPORTED_LANGUAGES[lang] for lang in target_langs])}")
    print("="*80)
    confirm = input("\n翻訳を開始しますか？ (yes/no): ").strip().lower()
    
    if confirm not in ['yes', 'y']:
        print("❌ キャンセルしました")
        return
    
    # Translate
    translate_xcstrings(file_path, target_langs)
    
    print("\n✅ 処理が完了しました！")

if __name__ == "__main__":
    main()
