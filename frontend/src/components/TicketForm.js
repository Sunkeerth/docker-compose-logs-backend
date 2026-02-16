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
