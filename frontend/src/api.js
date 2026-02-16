import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
});

export const fetchTickets = (params) => api.get('/tickets/', { params });
export const createTicket = (data) => api.post('/tickets/', data);
export const updateTicket = (id, data) => api.patch(`/tickets/${id}/`, data);
export const fetchStats = () => api.get('/tickets/stats/');
export const classifyDescription = (description) => api.post('/tickets/classify/', { description });
