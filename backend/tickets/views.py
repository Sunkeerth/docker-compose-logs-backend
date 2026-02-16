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
