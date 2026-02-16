import os
import json
import logging
from openai import OpenAI

logger = logging.getLogger(__name__)

def classify_description(description):
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        logger.error("OPENAI_API_KEY not set")
        return None, None

    client = OpenAI(api_key=api_key)

    prompt = f"""
You are a ticket classifier. Given a support ticket description, classify it into one of these categories: billing, technical, account, general.
Also assign a priority: low, medium, high, critical.
Respond with only a JSON object like: {{"category": "...", "priority": "..."}}
Description: {description}
"""
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=50,
        )
        content = response.choices[0].message.content.strip()
        result = json.loads(content)
        category = result.get('category')
        priority = result.get('priority')

        # Validate against allowed choices
        valid_categories = ['billing', 'technical', 'account', 'general']
        valid_priorities = ['low', 'medium', 'high', 'critical']
        if category not in valid_categories:
            category = None
        if priority not in valid_priorities:
            priority = None
        return category, priority
    except Exception as e:
        logger.exception("LLM call failed")
        return None, None
