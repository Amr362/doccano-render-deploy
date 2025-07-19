"""
Gmail authentication settings for Doccano
This module provides custom authentication backend to restrict access to specific Gmail domains
"""
import os
from django.contrib.auth.backends import ModelBackend
from django.contrib.auth.models import User
from django.core.exceptions import PermissionDenied


class GmailDomainBackend(ModelBackend):
    """
    Custom authentication backend that restricts access to specific Gmail domains
    """
    
    def authenticate(self, request, username=None, password=None, **kwargs):
        # Get allowed Gmail domains from environment variable
        allowed_domains = os.environ.get('ALLOWED_GMAIL_DOMAINS', 'gmail.com').split(',')
        allowed_domains = [domain.strip() for domain in allowed_domains]
        
        # Check if username (email) ends with allowed domain
        if username and '@' in username:
            domain = username.split('@')[1].lower()
            if domain not in allowed_domains:
                raise PermissionDenied(f"Access denied. Only {', '.join(allowed_domains)} emails are allowed.")
        
        # Call the parent authenticate method
        return super().authenticate(request, username, password, **kwargs)
    
    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None


def create_gmail_user_if_not_exists(email, password=None):
    """
    Create a user with Gmail email if it doesn't exist and is from allowed domain
    """
    allowed_domains = os.environ.get('ALLOWED_GMAIL_DOMAINS', 'gmail.com').split(',')
    allowed_domains = [domain.strip() for domain in allowed_domains]
    
    if '@' in email:
        domain = email.split('@')[1].lower()
        if domain in allowed_domains:
            user, created = User.objects.get_or_create(
                username=email,
                defaults={
                    'email': email,
                    'is_active': True,
                }
            )
            if created and password:
                user.set_password(password)
                user.save()
            return user
    return None

