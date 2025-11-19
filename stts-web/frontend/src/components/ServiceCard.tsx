import React from 'react';
import { Service, ServiceStatus } from '../types';

interface ServiceCardProps {
  service: Service;
}

export const ServiceCard: React.FC<ServiceCardProps> = ({ service }) => {
  const statusClass = ServiceStatus[service.status].toLowerCase();

  const handleClick = () => {
    window.open(service.url, '_blank', 'noopener,noreferrer');
  };

  return (
    <div
      className={`service-card status-${statusClass}`}
      onClick={handleClick}
      role="button"
      tabIndex={0}
    >
      <div className="service-header">
        <h3 className="service-name">{service.name}</h3>
        <span className={`status-badge ${statusClass}`}>
          {service.statusName}
        </span>
      </div>
      <p className="service-message">{service.message}</p>
    </div>
  );
};
