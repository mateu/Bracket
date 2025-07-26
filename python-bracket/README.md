# Python Bracket - NCAA Tournament Bracket API

A modern Python implementation of the NCAA Basketball Tournament Bracket system, built with FastAPI and SQLAlchemy for rapid development and excellent developer experience.

## Features

- **FastAPI framework** with automatic OpenAPI documentation
- **SQLAlchemy 2.0** with async support and type hints
- **Pydantic v2** for data validation and serialization
- **JWT authentication** with bcrypt password hashing
- **Multi-database support** (PostgreSQL, SQLite)
- **Async/await** throughout for high performance
- **Type hints** everywhere for better IDE support
- **Automatic API documentation** with Swagger UI
- **Docker support** with multi-stage builds
- **Comprehensive testing** with pytest

## Architecture

```
python-bracket/
├── app/
│   ├── models/          # SQLAlchemy models
│   ├── routers/         # API route handlers
│   ├── core/           # Core configuration & database
│   ├── auth/           # Authentication utilities
│   ├── tournament/     # Tournament business logic
│   └── main.py         # FastAPI application
├── tests/              # Test suite
└── docker/            # Docker configuration
```

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start with PostgreSQL
docker-compose up -d

# Or start with SQLite
docker-compose --profile sqlite up -d python-bracket-sqlite
```

### Manual Setup

1. **Install Python 3.11+** (if not already installed)

2. **Create virtual environment:**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies:**
```bash
pip install -r requirements.txt
```

4. **Set environment variables:**
```bash
cp .env.example .env
# Edit .env with your settings
```

5. **Run the application:**
```bash
python -m uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000` with automatic documentation at `http://localhost:8000/docs`.

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `GET /api/v1/auth/profile` - Get user profile (protected)

### Tournament
- `GET /api/v1/bracket/` - Get tournament bracket
- `GET /api/v1/bracket/teams` - Get all teams
- `GET /api/v1/bracket/regions` - Get all regions
- `GET /api/v1/bracket/leaderboard` - Get current leaderboard

### Player Actions (Protected)
- `GET /api/v1/bracket/player/{id}` - Get player's bracket
- `POST /api/v1/bracket/pick` - Make a pick

### Admin Actions (Admin Only)
- `PUT /api/v1/bracket/admin/game/{id}/result` - Update game result

## API Usage Examples

### Register a new user
```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
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
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "login": "john_doe",
    "password": "password123"
  }'
```

### Make a pick (requires authentication)
```bash
curl -X POST http://localhost:8000/api/v1/bracket/pick \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "game_id": 1,
    "team_id": 5
  }'
```

## Database Models

Built with SQLAlchemy 2.0 and modern Python type hints:

- **Region**: Tournament regions with relationships
- **Team**: Tournament teams with seeding information
- **Player**: User accounts with secure authentication
- **Game**: Tournament games with result tracking
- **Pick**: Player predictions with validation
- **Tournament**: Tournament metadata and state
- **RegionScore**: Regional scoring tracking
- **Session**: User session management

## Configuration

Environment variables (see `.env.example`):

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///./bracket.db` | Database connection string |
| `SECRET_KEY` | - | JWT secret key (required) |
| `DEBUG` | `false` | Enable debug mode |
| `PORT` | `8000` | Server port |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` | JWT token expiration |

## Development

### Running tests
```bash
pytest
```

### Code formatting
```bash
black app/
isort app/
```

### Type checking
```bash
mypy app/
```

### Running with hot reload
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Python-Specific Features

### Modern Python Features
- **Type hints** throughout for better IDE support and error prevention
- **Pydantic v2** for fast data validation and serialization
- **SQLAlchemy 2.0** with modern async/await syntax
- **FastAPI** with automatic OpenAPI documentation generation
- **Async/await** for high-performance I/O operations

### Developer Experience
- **Automatic API documentation** at `/docs` (Swagger UI) and `/redoc`
- **Hot reload** during development
- **Rich error messages** with detailed validation feedback
- **IDE support** with full type checking and autocompletion
- **Interactive testing** with built-in API documentation

### Performance Benefits
- **Async database operations** for better concurrency
- **Pydantic serialization** optimized in Rust
- **FastAPI performance** comparable to Node.js and Go
- **Efficient JSON handling** with orjson support
- **Connection pooling** with SQLAlchemy

## Security Features

- **JWT-based authentication** with configurable expiration
- **Password hashing** with bcrypt and salt
- **SQL injection prevention** with SQLAlchemy ORM
- **Input validation** with Pydantic models
- **CORS configuration** for cross-origin requests
- **Environment-based configuration** for secrets

## Testing

Comprehensive test suite with pytest:

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app

# Run specific test file
pytest tests/test_auth.py

# Run with verbose output
pytest -v
```

## Deployment

### Production with Gunicorn
```bash
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

### Docker Production
```bash
docker build -t python-bracket .
docker run -p 8000:8000 python-bracket
```

### Environment Variables for Production
```bash
export SECRET_KEY="your-very-long-random-secret-key"
export DATABASE_URL="postgresql://user:pass@localhost:5432/bracket"
export DEBUG=false
```

## Tournament Logic

Implements the complete NCAA tournament structure:

- **64-team single elimination** bracket
- **Progressive scoring system** with increasing point values
- **Real-time score calculations** with efficient queries
- **Pick validation** to ensure game integrity
- **Admin controls** for game result updates

## API Documentation

FastAPI automatically generates comprehensive API documentation:

- **Swagger UI**: Available at `/docs`
- **ReDoc**: Available at `/redoc`
- **OpenAPI JSON**: Available at `/openapi.json`

The documentation includes:
- All endpoints with request/response schemas
- Authentication requirements
- Example requests and responses
- Interactive testing interface

## Why Python/FastAPI?

Python with FastAPI was chosen for this implementation because:

- **Rapid Development**: Python's expressiveness enables quick feature development
- **Type Safety**: Modern Python with type hints provides compile-time error checking
- **Performance**: FastAPI offers performance comparable to Node.js and Go
- **Documentation**: Automatic API documentation generation
- **Ecosystem**: Rich ecosystem of packages for web development
- **Developer Experience**: Excellent tooling and IDE support
- **Testing**: Comprehensive testing frameworks and tools

This implementation demonstrates Python's capabilities for building high-performance, well-documented APIs while maintaining the same functionality as the original Perl application with modern development practices.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass with `pytest`
5. Format code with `black` and `isort`
6. Type check with `mypy`
7. Submit a pull request

## License

This project maintains the same license as the original Perl implementation.

