import React, { useState, useEffect, useMemo } from 'react';
import { ServiceCard } from './components/ServiceCard';
import { Service, ApiResponse, ServiceStatus } from './types';
import './styles/App.css';

function App() {
  const [services, setServices] = useState<Service[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [refreshing, setRefreshing] = useState(false);

  const fetchServices = async () => {
    try {
      const response = await fetch('/api/services');
      const data: ApiResponse = await response.json();

      if (data.success && data.services) {
        setServices(data.services);
        setError(null);
      } else {
        setError(data.error || 'Failed to load services');
      }
    } catch (err) {
      setError('Failed to connect to the server');
      console.error('Error fetching services:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      const response = await fetch('/api/services/update-all', {
        method: 'POST',
      });
      const data: ApiResponse = await response.json();

      if (data.success && data.services) {
        setServices(data.services);
      }
    } catch (err) {
      console.error('Error refreshing services:', err);
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchServices();
    // Auto-refresh every 60 seconds
    const interval = setInterval(fetchServices, 60000);
    return () => clearInterval(interval);
  }, []);

  const filteredServices = useMemo(() => {
    if (!searchTerm) return services;
    const term = searchTerm.toLowerCase();
    return services.filter(
      (service) =>
        service.name.toLowerCase().includes(term) ||
        service.message.toLowerCase().includes(term)
    );
  }, [services, searchTerm]);

  const stats = useMemo(() => {
    const counts = {
      good: 0,
      issues: 0,
      maintenance: 0,
      undetermined: 0,
    };

    services.forEach((service) => {
      if (service.status === ServiceStatus.Good) {
        counts.good++;
      } else if (
        service.status === ServiceStatus.Minor ||
        service.status === ServiceStatus.Major ||
        service.status === ServiceStatus.Notice
      ) {
        counts.issues++;
      } else if (service.status === ServiceStatus.Maintenance) {
        counts.maintenance++;
      } else {
        counts.undetermined++;
      }
    });

    return counts;
  }, [services]);

  if (loading) {
    return (
      <div className="app">
        <div className="loading">Loading services...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="app">
        <div className="error">
          <h2>Error</h2>
          <p>{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <h1>STTS - Service Status Monitor</h1>
        <p>Real-time monitoring of cloud service status pages</p>
      </header>

      <div className="controls">
        <input
          type="text"
          className="search-input"
          placeholder="Search services..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
        <button
          className="refresh-button"
          onClick={handleRefresh}
          disabled={refreshing}
        >
          {refreshing ? 'Refreshing...' : 'Refresh All'}
        </button>
      </div>

      <div className="stats">
        <div className="stat">
          <span className="stat-label">Total:</span>
          <span className="stat-value">{services.length}</span>
        </div>
        <div className="stat">
          <span className="stat-label">Operational:</span>
          <span className="stat-value" style={{ color: '#4caf50' }}>
            {stats.good}
          </span>
        </div>
        <div className="stat">
          <span className="stat-label">Issues:</span>
          <span className="stat-value" style={{ color: '#ff9800' }}>
            {stats.issues}
          </span>
        </div>
        {stats.maintenance > 0 && (
          <div className="stat">
            <span className="stat-label">Maintenance:</span>
            <span className="stat-value">{stats.maintenance}</span>
          </div>
        )}
      </div>

      {filteredServices.length === 0 ? (
        <div className="no-services">
          No services found matching "{searchTerm}"
        </div>
      ) : (
        <div className="services-grid">
          {filteredServices.map((service) => (
            <ServiceCard key={service.id} service={service} />
          ))}
        </div>
      )}
    </div>
  );
}

export default App;
