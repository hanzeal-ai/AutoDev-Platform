"""Shared async retry with exponential backoff."""

import asyncio
import logging

logger = logging.getLogger(__name__)

MAX_RETRIES = 2
RETRY_DELAY_BASE = 2.0  # seconds


async def retry_async(fn, retries=MAX_RETRIES):
    """Retry an async callable with exponential backoff."""
    last_error = None
    for attempt in range(retries + 1):
        try:
            return await fn()
        except Exception as e:
            last_error = e
            if attempt < retries:
                delay = RETRY_DELAY_BASE * (2 ** attempt)
                logger.warning(f"Attempt {attempt + 1} failed: {e}, retrying in {delay}s")
                await asyncio.sleep(delay)
    raise last_error
