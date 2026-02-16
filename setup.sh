#!/bin/bash

# Exit on error
set -e

echo "Creating Support Ticket System project structure..."

# Create root directories
mkdir -p backend/backend backend/tickets/migrations backend/tickets
mkdir -p frontend/public frontend/src/components
mkdir -p frontend/src

# ==================== BACKEND FILES ====================

# backend/Dockerfile
cat > backend/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

COPY wait-for-it.sh /wait-for-it.sh
RUN chmod +x /wait-for-it.sh

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
EOF

# backend/requirements.txt
cat > backend/requirements.txt << 'EOF'
Django==4.2.7
djangorestframework==3.14.0
psycopg2-binary==2.9.9
openai==1.3.0
django-cors-headers==4.3.1
EOF

# backend/manage.py
cat > backend/manage.py << 'EOF'
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys

def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed?"
        ) from exc
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
EOF

# backend/backend/settings.py
cat > backend/backend/settings.py << 'EOF'
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-!-dev-only-change-in-production'
DEBUG = True
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'tickets',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('POSTGRES_NAME'),
        'USER': os.environ.get('POSTGRES_USER'),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD'),
        'HOST': os.environ.get('POSTGRES_HOST', 'db'),
        'PORT': 5432,
    }
}

AUTH_PASSWORD_VALIDATORS = []

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

CORS_ALLOW_ALL_ORIGINS = True
EOF

# backend/backend/urls.py
cat > backend/backend/urls.py << 'EOF'
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('tickets.urls')),
]
EOF

# backend/backend/wsgi.py
cat > backend/backend/wsgi.py << 'EOF'
"""
WSGI config for backend project.
"""
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
application = get_wsgi_application()
EOF

# backend/tickets/models.py
cat > backend/tickets/models.py << 'EOF'
from django.db import models

class Ticket(models.Model):
    CATEGORY_CHOICES = [
        ('billing', 'Billing'),
        ('technical', 'Technical'),
        ('account', 'Account'),
        ('general', 'General'),
    ]
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ]
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
        ('closed', 'Closed'),
    ]

    title = models.CharField(max_length=200)
    description = models.TextField()
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title
EOF

# backend/tickets/serializers.py
cat > backend/tickets/serializers.py << 'EOF'
from rest_framework import serializers
from .models import Ticket

class TicketSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ticket
        fields = '__all__'
        read_only_fields = ('created_at',)
EOF

# backend/tickets/llm_client.py
cat > backend/tickets/llm_client.py << 'EOF'
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
EOF

# backend/tickets/views.py
cat > backend/tickets/views.py << 'EOF'
from django.db.models import Count, Q
from django.utils import timezone
from rest_framework import generics
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Ticket
from .serializers import TicketSerializer
from .llm_client import classify_description

class TicketListCreate(generics.ListCreateAPIView):
    queryset = Ticket.objects.all().order_by('-created_at')
    serializer_class = TicketSerializer

    def get_queryset(self):
        queryset = super().get_queryset()
        category = self.request.query_params.get('category')
        priority = self.request.query_params.get('priority')
        status = self.request.query_params.get('status')
        search = self.request.query_params.get('search')

        if category:
            queryset = queryset.filter(category=category)
        if priority:
            queryset = queryset.filter(priority=priority)
        if status:
            queryset = queryset.filter(status=status)
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search) | Q(description__icontains=search)
            )
        return queryset

class TicketRetrieveUpdate(generics.RetrieveUpdateAPIView):
    queryset = Ticket.objects.all()
    serializer_class = TicketSerializer

@api_view(['POST'])
def classify(request):
    description = request.data.get('description')
    if not description:
        return Response({'error': 'description required'}, status=400)

    category, priority = classify_description(description)
    return Response({
        'suggested_category': category,
        'suggested_priority': priority
    })

@api_view(['GET'])
def stats(request):
    total = Ticket.objects.count()
    open_tickets = Ticket.objects.filter(status='open').count()

    first = Ticket.objects.order_by('created_at').first()
    if first:
        days = (timezone.now() - first.created_at).days or 1
        avg_per_day = total / days
    else:
        avg_per_day = 0

    priority_data = Ticket.objects.values('priority').annotate(count=Count('priority'))
    category_data = Ticket.objects.values('category').annotate(count=Count('category'))

    priority_breakdown = {p: 0 for p, _ in Ticket.PRIORITY_CHOICES}
    category_breakdown = {c: 0 for c, _ in Ticket.CATEGORY_CHOICES}

    for item in priority_data:
        priority_breakdown[item['priority']] = item['count']
    for item in category_data:
        category_breakdown[item['category']] = item['count']

    return Response({
        'total_tickets': total,
        'open_tickets': open_tickets,
        'avg_tickets_per_day': round(avg_per_day, 1),
        'priority_breakdown': priority_breakdown,
        'category_breakdown': category_breakdown,
    })
EOF

# backend/tickets/urls.py
cat > backend/tickets/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path('tickets/', views.TicketListCreate.as_view(), name='ticket-list'),
    path('tickets/<int:pk>/', views.TicketRetrieveUpdate.as_view(), name='ticket-detail'),
    path('tickets/stats/', views.stats, name='ticket-stats'),
    path('tickets/classify/', views.classify, name='ticket-classify'),
]
EOF

# backend/tickets/apps.py
cat > backend/tickets/apps.py << 'EOF'
from django.apps import AppConfig

class TicketsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'tickets'
EOF

# backend/tickets/admin.py
cat > backend/tickets/admin.py << 'EOF'
from django.contrib import admin
from .models import Ticket

admin.site.register(Ticket)
EOF

# backend/tickets/migrations/__init__.py (empty)
touch backend/tickets/migrations/__init__.py

# backend/wait-for-it.sh
cat > backend/wait-for-it.sh << 'EOF'
#!/bin/sh
# wait-for-postgres.sh
set -e

host="$1"
shift
cmd="$@"

until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$host" -U "$POSTGRES_USER" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - executing command"
exec $cmd
EOF

chmod +x backend/wait-for-it.sh

# ==================== FRONTEND FILES ====================

# frontend/Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install

COPY . .

EXPOSE 3000

ENV CHOKIDAR_USEPOLLING=true

CMD ["npm", "start"]
EOF

# frontend/package.json
cat > frontend/package.json << 'EOF'
{
  "name": "frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "axios": "^1.6.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "proxy": "http://backend:8000"
}
EOF

# frontend/public/index.html
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Support Ticket System</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOF

# frontend/src/index.js
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# frontend/src/api.js
cat > frontend/src/api.js << 'EOF'
import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
});

export const fetchTickets = (params) => api.get('/tickets/', { params });
export const createTicket = (data) => api.post('/tickets/', data);
export const updateTicket = (id, data) => api.patch(`/tickets/${id}/`, data);
export const fetchStats = () => api.get('/tickets/stats/');
export const classifyDescription = (description) => api.post('/tickets/classify/', { description });
EOF

# frontend/src/App.js
cat > frontend/src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import TicketForm from './components/TicketForm';
import TicketList from './components/TicketList';
import StatsDashboard from './components/StatsDashboard';
import { fetchTickets, fetchStats } from './api';

function App() {
  const [tickets, setTickets] = useState([]);
  const [stats, setStats] = useState(null);
  const [filters, setFilters] = useState({ category: '', priority: '', status: '', search: '' });

  const loadTickets = () => {
    fetchTickets(filters).then(res => setTickets(res.data));
  };

  const loadStats = () => {
    fetchStats().then(res => setStats(res.data));
  };

  useEffect(() => {
    loadTickets();
    loadStats();
  }, [filters]);

  const handleTicketCreated = () => {
    loadTickets();
    loadStats();
  };

  const handleTicketUpdate = () => {
    loadTickets();
  };

  return (
    <div style={{ padding: '20px' }}>
      <h1>Support Ticket System</h1>
      <StatsDashboard stats={stats} />
      <TicketForm onTicketCreated={handleTicketCreated} />
      <TicketList
        tickets={tickets}
        filters={filters}
        onFilterChange={setFilters}
        onTicketUpdate={handleTicketUpdate}
      />
    </div>
  );
}

export default App;
EOF

# frontend/src/components/TicketForm.js
cat > frontend/src/components/TicketForm.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { createTicket, classifyDescription } from '../api';

function TicketForm({ onTicketCreated }) {
  const [form, setForm] = useState({
    title: '',
    description: '',
    category: '',
    priority: '',
  });
  const [classifying, setClassifying] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!form.description.trim()) return;
    const handler = setTimeout(() => {
      setClassifying(true);
      classifyDescription(form.description)
        .then(res => {
          const { suggested_category, suggested_priority } = res.data;
          setForm(prev => ({
            ...prev,
            category: suggested_category || prev.category,
            priority: suggested_priority || prev.priority,
          }));
        })
        .catch(err => console.error('Classification failed', err))
        .finally(() => setClassifying(false));
    }, 500);
    return () => clearTimeout(handler);
  }, [form.description]);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await createTicket(form);
      setForm({ title: '', description: '', category: '', priority: '' });
      onTicketCreated();
    } catch (err) {
      console.error('Create failed', err);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} style={{ marginBottom: '30px' }}>
      <h2>Submit a Ticket</h2>
      <div>
        <label>Title (max 200):</label><br />
        <input
          type="text"
          name="title"
          value={form.title}
          onChange={handleChange}
          maxLength="200"
          required
        />
      </div>
      <div>
        <label>Description:</label><br />
        <textarea
          name="description"
          value={form.description}
          onChange={handleChange}
          rows="4"
          cols="50"
          required
        />
        {classifying && <span> (getting suggestions...)</span>}
      </div>
      <div>
        <label>Category:</label><br />
        <select name="category" value={form.category} onChange={handleChange} required>
          <option value="">Select</option>
          <option value="billing">Billing</option>
          <option value="technical">Technical</option>
          <option value="account">Account</option>
          <option value="general">General</option>
        </select>
      </div>
      <div>
        <label>Priority:</label><br />
        <select name="priority" value={form.priority} onChange={handleChange} required>
          <option value="">Select</option>
          <option value="low">Low</option>
          <option value="medium">Medium</option>
          <option value="high">High</option>
          <option value="critical">Critical</option>
        </select>
      </div>
      <button type="submit" disabled={submitting}>
        {submitting ? 'Submitting...' : 'Submit Ticket'}
      </button>
    </form>
  );
}

export default TicketForm;
EOF

# frontend/src/components/TicketList.js
cat > frontend/src/components/TicketList.js << 'EOF'
import React from 'react';
import { updateTicket } from '../api';

function TicketList({ tickets, filters, onFilterChange, onTicketUpdate }) {
  const handleFilterChange = (e) => {
    onFilterChange({ ...filters, [e.target.name]: e.target.value });
  };

  const handleStatusChange = (ticketId, newStatus) => {
    updateTicket(ticketId, { status: newStatus }).then(() => onTicketUpdate());
  };

  return (
    <div>
      <h2>Tickets</h2>
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        <input
          type="text"
          name="search"
          placeholder="Search..."
          value={filters.search}
          onChange={handleFilterChange}
        />
        <select name="category" value={filters.category} onChange={handleFilterChange}>
          <option value="">All Categories</option>
          <option value="billing">Billing</option>
          <option value="technical">Technical</option>
          <option value="account">Account</option>
          <option value="general">General</option>
        </select>
        <select name="priority" value={filters.priority} onChange={handleFilterChange}>
          <option value="">All Priorities</option>
          <option value="low">Low</option>
          <option value="medium">Medium</option>
          <option value="high">High</option>
          <option value="critical">Critical</option>
        </select>
        <select name="status" value={filters.status} onChange={handleFilterChange}>
          <option value="">All Statuses</option>
          <option value="open">Open</option>
          <option value="in_progress">In Progress</option>
          <option value="resolved">Resolved</option>
          <option value="closed">Closed</option>
        </select>
      </div>
      <table border="1" cellPadding="8" style={{ borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th>Title</th>
            <th>Description</th>
            <th>Category</th>
            <th>Priority</th>
            <th>Status</th>
            <th>Created</th>
          </tr>
        </thead>
        <tbody>
          {tickets.map(ticket => (
            <tr key={ticket.id}>
              <td>{ticket.title}</td>
              <td>{ticket.description.substring(0, 50)}...</td>
              <td>{ticket.category}</td>
              <td>{ticket.priority}</td>
              <td>
                <select
                  value={ticket.status}
                  onChange={(e) => handleStatusChange(ticket.id, e.target.value)}
                >
                  <option value="open">Open</option>
                  <option value="in_progress">In Progress</option>
                  <option value="resolved">Resolved</option>
                  <option value="closed">Closed</option>
                </select>
              </td>
              <td>{new Date(ticket.created_at).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default TicketList;
EOF

# frontend/src/components/StatsDashboard.js
cat > frontend/src/components/StatsDashboard.js << 'EOF'
import React from 'react';

function StatsDashboard({ stats }) {
  if (!stats) return <div>Loading stats...</div>;

  return (
    <div style={{ border: '1px solid #ccc', padding: '15px', marginBottom: '20px' }}>
      <h3>Stats Dashboard</h3>
      <p><strong>Total Tickets:</strong> {stats.total_tickets}</p>
      <p><strong>Open Tickets:</strong> {stats.open_tickets}</p>
      <p><strong>Avg Tickets/Day:</strong> {stats.avg_tickets_per_day}</p>
      <div>
        <strong>Priority Breakdown:</strong>
        <ul>
          {Object.entries(stats.priority_breakdown).map(([k, v]) => (
            <li key={k}>{k}: {v}</li>
          ))}
        </ul>
      </div>
      <div>
        <strong>Category Breakdown:</strong>
        <ul>
          {Object.entries(stats.category_breakdown).map(([k, v]) => (
            <li key={k}>{k}: {v}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default StatsDashboard;
EOF

# ==================== DOCKER COMPOSE ====================

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: ticket_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    command: >
      sh -c "python manage.py migrate &&
             python manage.py runserver 0.0.0.0:8000"
    volumes:
      - ./backend:/app
    ports:
      - "8000:8000"
    environment:
      POSTGRES_NAME: ticket_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_HOST: db
      OPENAI_API_KEY: ${OPENAI_API_KEY}
    depends_on:
      db:
        condition: service_healthy

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - CHOKIDAR_USEPOLLING=true
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules

volumes:
  postgres_data:
EOF

# ==================== README ====================

cat > README.md << 'EOF'
# Support Ticket System

This is a full-stack support ticket system with LLM-powered auto-categorization.

## Setup

1. Clone the repository (or unzip the project).
2. Make sure you have Docker and Docker Compose installed.
3. Set your OpenAI API key as an environment variable:
   ```bash
   export OPENAI_API_KEY=your_key_here


EOF
