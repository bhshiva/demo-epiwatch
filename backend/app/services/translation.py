import logging
import os
from typing import Optional

_has_genai = False
try:
    from google import genai
    _has_genai = True
except ImportError:
    pass

_has_deep_translator = False
try:
    from deep_translator import GoogleTranslator
    _has_deep_translator = True
except ImportError:
    pass

logger = logging.getLogger(__name__)


class TranslationService:
    @staticmethod
    def translate_to_english(text: Optional[str], source_lang: str = "auto") -> Optional[str]:
        if not text or not text.strip():
            return text

        # If text is already strictly ASCII (English numbers/punctuation/latin letters), return as is
        if all(ord(char) < 128 for char in text):
            return text

        # 1. Try Gemini via SDK if API key available
        api_key = os.getenv("GEMINI_API_KEY")
        if _has_genai and api_key:
            try:
                client = genai.Client(api_key=api_key)
                prompt = (
                    f"Translate the following medical/clinical text to English. "
                    f"Return ONLY the translated English text, with no explanations, "
                    f"no quotes, and no extra formatting:\n\n{text}"
                )
                res = client.models.generate_content(
                    model="gemini-3.6-flash",
                    contents=prompt,
                )
                if res and res.text and res.text.strip():
                    return res.text.strip()
            except Exception:
                logger.warning("Gemini translation failed, falling back to deep_translator", exc_info=True)

        # 2. Fallback to deep_translator GoogleTranslator.
        # Always use source="auto" because deep_translator rejects BCP-47
        # codes (e.g. "hi") — it needs full language names ("hindi") or "auto".
        # Auto-detect is also more robust when the UI language doesn't match
        # the language the clinician actually typed in.
        if _has_deep_translator:
            try:
                translated = GoogleTranslator(source="auto", target="en").translate(text)
                if translated and translated.strip():
                    return translated.strip()
            except Exception:
                logger.warning("deep_translator translation failed", exc_info=True)

        return text

