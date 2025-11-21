#!/bin/bash
# PostgreSQL Helper Script for ReAgenyx
# Usage: ./db-helper.sh [command]

PSQL="/opt/homebrew/opt/postgresql@15/bin/psql"
DB_NAME="reagenyx"
DB_USER=$(whoami)

case "$1" in
    "connect")
        echo "🔌 Connecting to database..."
        $PSQL -U $DB_USER -d $DB_NAME
        ;;
    "list")
        echo "📋 Listing tables..."
        $PSQL -U $DB_USER -d $DB_NAME -c "\dt"
        ;;
    "waitlist")
        echo "📧 Waitlist entries:"
        $PSQL -U $DB_USER -d $DB_NAME -c "SELECT id, email, signed_up_at, source FROM waitlist ORDER BY signed_up_at DESC LIMIT 10;"
        ;;
    "count")
        echo "📊 Total waitlist signups:"
        $PSQL -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total FROM waitlist;"
        ;;
    "export")
        echo "💾 Exporting waitlist to waitlist.csv..."
        $PSQL -U $DB_USER -d $DB_NAME -c "\COPY waitlist TO 'waitlist.csv' CSV HEADER"
        echo "✅ Exported to waitlist.csv"
        ;;
    "migrate")
        if [ -z "$2" ]; then
            echo "❌ Usage: ./db-helper.sh migrate <migration-file>"
            exit 1
        fi
        echo "🔄 Running migration: $2"
        $PSQL -U $DB_USER -d $DB_NAME -f "$2"
        ;;
    "test")
        echo "🧪 Testing database connection..."
        $PSQL -U $DB_USER -d $DB_NAME -c "SELECT NOW();"
        ;;
    *)
        echo "🗄️  LenKinVerse Database Helper"
        echo ""
        echo "Usage: ./db-helper.sh [command]"
        echo ""
        echo "Commands:"
        echo "  connect   - Connect to database (psql)"
        echo "  list      - List all tables"
        echo "  waitlist  - Show recent waitlist entries"
        echo "  count     - Show total waitlist signups"
        echo "  export    - Export waitlist to CSV"
        echo "  migrate   - Run a migration file"
        echo "  test      - Test database connection"
        echo ""
        echo "Examples:"
        echo "  ./db-helper.sh connect"
        echo "  ./db-helper.sh waitlist"
        echo "  ./db-helper.sh migrate src/db/migrations/007_waitlist.sql"
        ;;
esac
