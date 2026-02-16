import React, { useState, useEffect } from 'react';
import TicketForm from './components/TicketForm';
import TicketList from './components/TicketList';
import StatsDashboard from './components/StatsDashboard';
import { fetchTickets, fetchStats } from './api';
import './App.css'; 

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
