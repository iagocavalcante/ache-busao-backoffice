# API Requirements and Development Documentation

## Project Overview

The "Ache o Busão" API is designed to track real-time bus locations in Belém, PA. Users can anonymously share their location when riding a bus, and other users can view the last known positions of buses on different routes.

## Core Features

### 1. Anonymous Location Tracking
- Users enter a bus and share their current location
- Location updates are collected every X minutes while user is on the bus
- All users remain anonymous - no personal identification required
- Device information is collected to prevent API abuse

### 2. Real-time Bus Positions
- Display last known position of buses on each route
- Use long polling for real-time updates
- Filter locations to ensure they're within valid bus routes
- Show active user count per route

### 3. Route Validation
- Validate that reported locations are within acceptable bus route boundaries
- Prevent false or malicious location reports
- Use PostGIS for spatial queries and route validation

## Technical Requirements

### Database Schema

#### Bus Routes Table
```sql
CREATE TABLE bus_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(7) NOT NULL, -- Hex color code
    number VARCHAR(10),
    stops TEXT[], -- Array of stop names
    route_geometry GEOMETRY(LINESTRING, 4326), -- PostGIS geometry for route path
    buffer_distance INTEGER DEFAULT 100, -- Buffer distance in meters for validation
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Device Sessions Table
```sql
CREATE TABLE device_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) NOT NULL, -- Unique device identifier
    device_info JSONB, -- Device information (OS, version, etc.)
    route_id VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    FOREIGN KEY (route_id) REFERENCES bus_routes(route_id)
);
```

#### Location Reports Table
```sql
CREATE TABLE location_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL, -- PostGIS point
    accuracy FLOAT, -- GPS accuracy in meters
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_valid BOOLEAN DEFAULT true, -- Whether location is within route bounds
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    FOREIGN KEY (session_id) REFERENCES device_sessions(id)
);
```

#### Rate Limiting Table
```sql
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) NOT NULL,
    endpoint VARCHAR(100) NOT NULL,
    request_count INTEGER DEFAULT 1,
    window_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(device_id, endpoint, window_start)
);
```

### API Endpoints

#### 1. Start Bus Session
```
POST /api/v1/bus/start-session
Content-Type: application/json

{
    "route_id": "belem-305",
    "device_info": {
        "platform": "ios",
        "version": "17.0",
        "app_version": "1.0.0",
        "device_model": "iPhone 14"
    },
    "initial_location": {
        "latitude": -1.4789,
        "longitude": -48.3789,
        "accuracy": 10.0
    }
}

Response:
{
    "session_id": "uuid-here",
    "route_info": {
        "id": "belem-305",
        "name": "305 UFPA / Icoaraci",
        "color": "#85C1E9"
    },
    "update_interval": 60000, // milliseconds
    "success": true
}
```

#### 2. Update Location
```
PUT /api/v1/bus/update-location/:session_id
Content-Type: application/json

{
    "location": {
        "latitude": -1.4789,
        "longitude": -48.3789,
        "accuracy": 10.0
    }
}

Response:
{
    "success": true,
    "is_valid_location": true,
    "next_update_in": 60000
}
```

#### 3. End Bus Session
```
DELETE /api/v1/bus/end-session/:session_id

Response:
{
    "success": true,
    "session_duration": 1800000 // milliseconds
}
```

#### 4. Get Bus Positions (Long Polling)
```
GET /api/v1/bus/positions?timeout=30000&last_update=2024-01-01T00:00:00Z

Response:
{
    "routes": [
        {
            "route_id": "belem-305",
            "name": "305 UFPA / Icoaraci",
            "color": "#85C1E9",
            "last_position": {
                "latitude": -1.4789,
                "longitude": -48.3789,
                "updated_at": "2024-01-01T12:00:00Z"
            },
            "active_users": 5,
            "stops": ["UFPA", "Icoaraci"]
        }
    ],
    "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 5. Get Route Information
```
GET /api/v1/routes

Response:
{
    "routes": [
        {
            "route_id": "belem-305",
            "name": "305 UFPA / Icoaraci",
            "description": "UFPA / Icoaraci",
            "color": "#85C1E9",
            "number": "305",
            "stops": ["UFPA", "Campus UFPA", "Reitoria", "Hospital Universitário", "Icoaraci"],
            "active_users": 5
        }
    ]
}
```

### Security & Anti-Abuse Measures

#### 1. Device Fingerprinting
- Collect device information to create unique fingerprints
- Track device behavior patterns
- Implement device-based rate limiting

#### 2. Location Validation
- Use PostGIS to validate locations are within route boundaries
- Implement buffer zones around routes (configurable distance)
- Reject locations that are too far from valid routes
- Detect unrealistic movement patterns (speed, distance)

#### 3. Rate Limiting
- Implement per-device rate limiting
- Different limits for different endpoints
- Sliding window approach for rate limiting
- Exponential backoff for repeated violations

#### 4. Session Management
- Sessions expire after inactivity
- Maximum session duration limits
- Track concurrent sessions per device
- Prevent session hijacking

### PostGIS Integration

#### Required Extensions
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
```

#### Spatial Indexes
```sql
CREATE INDEX idx_bus_routes_geometry ON bus_routes USING GIST (route_geometry);
CREATE INDEX idx_location_reports_location ON location_reports USING GIST (location);
```

#### Spatial Queries Examples
```sql
-- Check if location is within route buffer
SELECT EXISTS(
    SELECT 1 FROM bus_routes
    WHERE route_id = $1
    AND ST_DWithin(
        route_geometry,
        ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
        buffer_distance
    )
);

-- Get latest position for each route
SELECT DISTINCT ON (br.route_id)
    br.route_id,
    br.name,
    br.color,
    ST_X(lr.location) as longitude,
    ST_Y(lr.location) as latitude,
    lr.timestamp
FROM bus_routes br
JOIN device_sessions ds ON br.route_id = ds.route_id
JOIN location_reports lr ON ds.id = lr.session_id
WHERE ds.is_active = true
ORDER BY br.route_id, lr.timestamp DESC;
```

### Long Polling Implementation

#### Phoenix Channel Alternative
Instead of traditional long polling, consider using Phoenix Channels for better real-time performance:

```elixir
# Channel for real-time bus positions
defmodule AcheBusaoBackofficeWeb.BusPositionsChannel do
  use Phoenix.Channel

  def join("bus_positions", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("subscribe_route", %{"route_id" => route_id}, socket) do
    # Subscribe to route updates
    Phoenix.PubSub.subscribe(AcheBusaoBackoffice.PubSub, "route:#{route_id}")
    {:noreply, socket}
  end
end
```

### Development Phases

#### Phase 1: Core Infrastructure
1. Setup PostGIS extension
2. Create database migrations
3. Implement basic CRUD for routes
4. Setup device session management
5. Basic location validation

#### Phase 2: API Implementation
1. Implement all API endpoints
2. Add rate limiting middleware
3. Location validation with PostGIS
4. Session management
5. Basic long polling

#### Phase 3: Security & Optimization
1. Advanced device fingerprinting
2. Abuse detection algorithms
3. Performance optimization
4. Caching strategies
5. Monitoring and alerting

#### Phase 4: Advanced Features
1. Real-time updates with Phoenix Channels
2. Route prediction algorithms
3. Analytics and reporting
4. Mobile app integration
5. Admin dashboard

### Configuration

#### Environment Variables
```
# Database
DATABASE_URL=postgresql://user:pass@localhost/ache_busao_dev
POSTGIS_VERSION=3.3

# API Configuration
API_RATE_LIMIT_WINDOW=60000
API_RATE_LIMIT_MAX_REQUESTS=100
LOCATION_UPDATE_INTERVAL=60000
SESSION_TIMEOUT=3600000
ROUTE_BUFFER_DISTANCE=100

# Security
DEVICE_FINGERPRINT_SECRET=your-secret-key
SESSION_SECRET=your-session-secret
```

#### Mix Dependencies to Add
```elixir
# Add to mix.exs
{:geo, "~> 3.4"}, # GeoJSON support
{:geo_postgis, "~> 3.4"}, # PostGIS integration
{:hammer, "~> 6.0"}, # Rate limiting
{:phoenix_pubsub, "~> 2.0"}, # PubSub for real-time updates
{:jason, "~> 1.4"}, # JSON parsing
{:plug_crypto, "~> 1.2"}, # Crypto utilities
{:cachex, "~> 3.4"}, # Caching
```

### Testing Strategy

#### Unit Tests
- Route validation functions
- Location validation algorithms
- Device fingerprinting
- Rate limiting logic

#### Integration Tests
- API endpoint functionality
- Database spatial queries
- Session management
- Long polling behavior

#### Performance Tests
- Load testing for concurrent users
- Spatial query performance
- Memory usage monitoring
- Database connection pooling

### Monitoring & Observability

#### Metrics to Track
- Active sessions per route
- Location update frequency
- API response times
- Rate limit violations
- Invalid location reports
- Database query performance

#### Alerting
- High rate limit violations
- Database connection issues
- Abnormal location patterns
- Performance degradation
- Session management problems

### Data Privacy & Compliance

#### Privacy Measures
- No personal identification stored
- Device IDs are hashed
- Location data retention policies
- Anonymous analytics only

#### Data Retention
- Location reports: 24 hours
- Device sessions: 7 days
- Rate limiting data: 24 hours
- Route data: Permanent

This documentation provides a comprehensive foundation for developing the bus tracking API. The implementation should be done incrementally, starting with the core infrastructure and gradually adding more sophisticated features.
