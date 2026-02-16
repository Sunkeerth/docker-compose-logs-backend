from django.urls import path
from . import views

urlpatterns = [
    path('tickets/', views.TicketListCreate.as_view(), name='ticket-list'),
    path('tickets/<int:pk>/', views.TicketRetrieveUpdate.as_view(), name='ticket-detail'),
    path('tickets/stats/', views.stats, name='ticket-stats'),
    path('tickets/classify/', views.classify, name='ticket-classify'),
]
