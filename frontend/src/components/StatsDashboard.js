import React from 'react';

function StatsDashboard({ stats }) {
  if (!stats) return <div>Loading stats...</div>;

  return (
    // 
    // <div style={{ border: '1px solid #ccc', padding: '15px', marginBottom: '20px' }}>
    <div className="stats-dashboard">
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
