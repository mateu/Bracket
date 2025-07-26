# Rust Bracket - NCAA Tournament Bracket API

A high-performance Rust implementation of the NCAA Basketball Tournament Bracket system, built with Axum and Sea-ORM for maximum type safety and performance.

## Features

- **Type-safe REST API** with Axum framework
- **Sea-ORM** for compile-time verified database queries
- **JWT authentication** with bcrypt password hashing
- **Multi-database support** (PostgreSQL, SQLite)
- **Async/await** throughout for high concurrency
- **Comprehensive error handling** with structured logging
- **Docker support** with multi-stage builds
- **Zero-cost abstractions** with Rust's performance guarantees

## Architecture

```
rust-bracket/
├── src/
│   ├── handlers/        # HTTP request handlers
│   ├── models/          # Sea-ORM entity models
│   ├── middleware/      # Authentication & CORS middleware
│   ├── database/        # Database connection & seeding
│   ├── auth/           # JWT & password utilities
│   ├── tournament/     # Tournament business logic
│   └── main.rs         # Application entry point
├── migrations/         # Database migrations
└── docker/            # Docker configuration
```

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start with PostgreSQL
docker-compose up -d

# Or start with SQLite
docker-compose --profile sqlite up -d rust-bracket-sqlite
```

### Manual Setup

1. **Install Rust** (if not already installed):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

2. **Set environment variables:**
```bash
export DATABASE_URL=sqlite://bracket.db
export RUST_LOG=debug
```

3. **Run the application:**
```bash
cargo run
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
curl -X POST http://localhost:3000/api/v1/auth/register \
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
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "login": "john_doe",
    "password": "password123"
  }'
```

### Make a pick (requires authentication)
```bash
curl -X POST http://localhost:3000/api/v1/bracket/pick \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "game_id": 1,
    "team_id": 5
  }'
```

## Database Models

Built with Sea-ORM for compile-time query verification:

- **Region**: Tournament regions with type-safe relationships
- **Team**: Tournament teams with seeding information
- **Player**: User accounts with secure authentication
- **Game**: Tournament games with result tracking
- **Pick**: Player predictions with validation
- **Tournament**: Tournament metadata and state

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite://bracket.db` | Database connection string |
| `PORT` | `3000` | Server port |
| `RUST_LOG` | `info` | Logging level |

## Development

### Running tests
```bash
cargo test
```

### Building for production
```bash
cargo build --release
```

### Database migrations
```bash
# Install sea-orm-cli
cargo install sea-orm-cli

# Generate migration
sea-orm-cli migrate generate create_tables

# Run migrations
sea-orm-cli migrate up
```

## Performance Benefits

Rust provides significant performance advantages:

- **Zero-cost abstractions**: No runtime overhead for safety features
- **Memory safety**: No garbage collector, predictable performance
- **Concurrency**: Async/await with excellent performance characteristics
- **Type safety**: Compile-time error prevention
- **Small binary size**: Optimized release builds

## Rust-Specific Features

### Type Safety
- **Compile-time query verification** with Sea-ORM
- **Strong typing** prevents runtime errors
- **Option types** eliminate null pointer exceptions
- **Result types** for explicit error handling

### Performance
- **Zero-copy deserialization** with serde
- **Efficient async runtime** with tokio
- **Memory-efficient** data structures
- **SIMD optimizations** where applicable

### Developer Experience
- **Excellent tooling** with cargo
- **Built-in testing** framework
- **Documentation generation** with rustdoc
- **Package management** with crates.io

## Security Features

- **Memory safety** by design
- **JWT-based authentication** with secure defaults
- **Password hashing** with bcrypt
- **SQL injection prevention** with Sea-ORM
- **Input validation** with validator crate

## Deployment

The application can be deployed using:

1. **Docker** - Multi-stage builds for minimal image size
2. **Binary** - Single executable with no dependencies
3. **Cloud platforms** - Deploy anywhere Rust runs
4. **Kubernetes** - Container orchestration ready

## Tournament Logic

Implements the complete NCAA tournament structure:

- **64-team single elimination**
- **Progressive scoring system**
- **Real-time calculations**
- **Type-safe game state management**
- **Efficient bracket traversal**

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure `cargo clippy` passes
5. Format code with `cargo fmt`
6. Submit a pull request

## Why Rust?

Rust was chosen for this implementation because:

- **Performance**: Near C/C++ performance with safety
- **Reliability**: Prevents entire classes of bugs at compile time
- **Concurrency**: Excellent async/await support
- **Ecosystem**: Rich crate ecosystem for web development
- **Future-proof**: Growing adoption in systems programming

This implementation demonstrates Rust's capabilities for building high-performance, type-safe web APIs while maintaining the same functionality as the original Perl application.

## License

This project maintains the same license as the original Perl implementation.

