# Go Bracket - NCAA Tournament Bracket API

A modern Go implementation of the NCAA Basketball Tournament Bracket system, featuring a REST API built with Gin and GORM.

## Features

- **RESTful API** with JWT authentication
- **Multi-database support** (PostgreSQL, SQLite)
- **Tournament bracket management** with automatic scoring
- **User registration and authentication**
- **Admin interface** for managing tournament results
- **Real-time leaderboard**
- **Docker support** for easy deployment

## Architecture

```
go-bracket/
├── cmd/server/          # Application entry point
├── internal/
│   ├── models/          # Database models
│   ├── handlers/        # HTTP handlers
│   ├── middleware/      # HTTP middleware
│   └── database/        # Database configuration
├── pkg/
│   ├── auth/           # Authentication utilities
│   └── tournament/     # Tournament business logic
├── configs/            # Configuration files
├── migrations/         # Database migrations
└── docker/            # Docker configuration
```

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start with PostgreSQL
docker-compose up -d

# Or start with SQLite
docker-compose --profile sqlite up -d bracket-sqlite
```

### Manual Setup

1. **Install dependencies:**
```bash
go mod download
```

2. **Set environment variables:**
```bash
export DB_DRIVER=sqlite
export DB_NAME=bracket.db
```

3. **Run the application:**
```bash
go run cmd/server/main.go
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `GET /api/v1/auth/profile` - Get user profile (protected)

### Tournament
- `GET /api/v1/bracket` - Get tournament bracket
- `GET /api/v1/teams` - Get all teams
- `GET /api/v1/regions` - Get all regions
- `GET /api/v1/leaderboard` - Get current leaderboard

### Player Actions (Protected)
- `GET /api/v1/bracket/player/:id` - Get player's bracket
- `POST /api/v1/bracket/pick` - Make a pick

### Admin Actions (Admin Only)
- `PUT /api/v1/admin/bracket/game/:id/result` - Update game result

## API Usage Examples

### Register a new user
```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "login": "john_doe",
    "password": "password123",
    "first_name": "John",
    "last_name": "Doe",
    "email": "john@example.com"
  }'
```

### Login
```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "login": "john_doe",
    "password": "password123"
  }'
```

### Make a pick (requires authentication)
```bash
curl -X POST http://localhost:8080/api/v1/bracket/pick \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "game_id": 1,
    "team_id": 5
  }'
```

### Get leaderboard
```bash
curl http://localhost:8080/api/v1/leaderboard
```

## Database Models

The application uses the following core models:

- **Region**: Tournament regions (East, Midwest, South, West)
- **Team**: Tournament teams with seeding
- **Player**: User accounts with authentication
- **Game**: Tournament games with results
- **Pick**: Player predictions for games
- **Tournament**: Tournament metadata

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_DRIVER` | `sqlite` | Database driver (sqlite, postgres) |
| `DB_HOST` | `localhost` | Database host |
| `DB_PORT` | `5432` | Database port |
| `DB_USER` | `bracket` | Database user |
| `DB_PASSWORD` | `` | Database password |
| `DB_NAME` | `bracket.db` | Database name |
| `DB_SSLMODE` | `disable` | SSL mode for PostgreSQL |
| `PORT` | `8080` | Server port |

## Development

### Running tests
```bash
go test ./...
```

### Building for production
```bash
CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o bracket ./cmd/server
```

## Deployment

The application can be deployed using:

1. **Docker** - Use the provided Dockerfile
2. **Docker Compose** - For development with PostgreSQL
3. **Binary** - Compile and run the binary directly
4. **Cloud platforms** - Deploy to AWS, GCP, Azure, etc.

## Tournament Logic

The bracket system supports:

- **64-team single elimination tournament**
- **4 regions with 16 teams each**
- **6 rounds**: First Round → Second Round → Sweet 16 → Elite 8 → Final Four → Championship
- **Progressive scoring**: Later rounds worth more points
- **Real-time score calculation**
- **Admin controls** for updating game results

## Security Features

- **JWT-based authentication**
- **Password hashing** with bcrypt
- **CORS support**
- **Admin role separation**
- **Input validation**

## Performance Considerations

- **Database indexing** on foreign keys
- **Efficient queries** with GORM preloading
- **Stateless design** for horizontal scaling
- **Connection pooling** for database connections

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project maintains the same license as the original Perl implementation.

