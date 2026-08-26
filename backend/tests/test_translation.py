import pytest
from app.services.translation import TranslationService

def test_ascii_english_unchanged():
    text = "High grade fever since 4 days and productive cough."
    assert TranslationService.translate_to_english(text) == text

def test_empty_or_none():
    assert TranslationService.translate_to_english(None) is None
    assert TranslationService.translate_to_english("") == ""
    assert TranslationService.translate_to_english("   ") == "   "

def test_translation_service_graceful_fallback():
    hindi_text = "तेज बुखार और खांसी"
    result = TranslationService.translate_to_english(hindi_text)
    assert isinstance(result, str)
    assert len(result) > 0
