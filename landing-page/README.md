# 🎮 LenKinVerse Landing Page

Beautiful, responsive landing page with email waitlist for early access signups.

---

## 📁 Structure

```
landing-page/
├── index.html           # Main landing page
├── css/
│   └── style.css       # All styles (dark theme, responsive)
├── js/
│   └── script.js       # Waitlist form + animations
├── assets/             # Images, favicons
└── README.md           # This file
```

---

## ✨ Features

### Design
- 🌙 **Dark theme** with purple gradient accents
- 📱 **Fully responsive** (mobile, tablet, desktop)
- ⚡ **Smooth animations** (scroll reveals, hover effects)
- 🎨 **Modern UI** with Inter font

### Sections
1. **Hero** - Main call-to-action with animated particles
2. **Features** - 6 key game features in cards
3. **How It Works** - 3-step gameplay explanation
4. **Game Economy** - Element rarity showcase
5. **Waitlist** - Email signup form
6. **Footer** - Links and legal

### Waitlist Form
- ✅ Email validation
- ✅ Backend API integration
- ✅ Success/error messaging
- ✅ Loading states
- ✅ Analytics ready (Google Analytics)

---

## 🚀 Quick Start

### 1. Open Locally

```bash
# Navigate to folder
cd landing-page

# Open in browser (any method):
open index.html
# or
python3 -m http.server 8000
# Then visit http://localhost:8000
```

### 2. Backend Connection

The form submits to `/api/waitlist` - make sure backend is running:

```bash
# Start backend (from project root)
cd backend
npm run dev

# Backend runs on http://localhost:3000
# Landing page should point to this URL
```

### 3. Database Setup

Run the waitlist migration:

```bash
cd backend
psql -U postgres -d lenkinverse -f src/db/migrations/007_waitlist.sql
```

---

## 🌐 Deployment

### Option 1: Static Hosting (Vercel / Netlify)

**Vercel:**
```bash
npm install -g vercel
cd landing-page
vercel
```

**Netlify:**
```bash
npm install -g netlify-cli
cd landing-page
netlify deploy
```

**Update API URL in `js/script.js`:**
```javascript
const response = await fetch('https://your-backend.com/api/waitlist', {
    method: 'POST',
    // ...
});
```

### Option 2: Same Server as Backend

```bash
# Copy landing page to backend public folder
cp -r landing-page backend/public

# Backend serves static files
# Add to backend/src/api/server.ts:
app.use(express.static('public'));
```

### Option 3: CDN (Cloudflare Pages / GitHub Pages)

1. Push to GitHub repository
2. Enable GitHub Pages: Settings → Pages → main branch
3. Your site: `https://username.github.io/LenKinVerse/`

---

## 🎨 Customization

### Colors

Edit `css/style.css` `:root` variables:

```css
:root {
    --primary: #8B5CF6;          /* Purple */
    --secondary: #10B981;        /* Green */
    --background: #0F172A;       /* Dark blue */
    /* ... */
}
```

### Content

Edit `index.html`:
- **Hero title**: Line 42
- **Features**: Lines 80-127
- **How It Works**: Lines 145-193
- **Footer links**: Lines 291-312

### Images

Add to `assets/` folder:
- `favicon.svg` - Browser icon
- `og-image.png` - Social media preview (1200×630px)
- Element icons for economy section

---

## 📊 Waitlist Data

### API Endpoints

**Join Waitlist:**
```
POST /api/waitlist
{
    "email": "user@example.com"
}
```

**Get Stats (Admin):**
```
GET /api/waitlist/stats
```

Response:
```json
{
    "total_signups": 1234,
    "signups_today": 56,
    "signups_week": 432,
    "first_signup": "2025-01-01T00:00:00Z",
    "latest_signup": "2025-11-19T10:30:00Z"
}
```

### Database

Table: `waitlist`

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| email | VARCHAR | User email (unique) |
| signed_up_at | TIMESTAMP | Signup time |
| source | VARCHAR | Signup source (landing-page, twitter, etc) |
| notified | BOOLEAN | Whether user was notified |

---

## 🔧 Maintenance

### Update Waitlist Count

Show real waitlist count on page:

```javascript
// In js/script.js
async function updateWaitlistCount() {
    const response = await fetch('/api/waitlist/stats');
    const data = await response.json();
    document.getElementById('waitlist-count').textContent = data.total_signups;
}
```

```html
<!-- In index.html -->
<div class="hero-badge">
    <span id="waitlist-count">500</span> people on waitlist
</div>
```

### Export Waitlist

```bash
# Export to CSV
psql -U postgres -d lenkinverse -c "\COPY waitlist TO 'waitlist.csv' CSV HEADER"
```

---

## 📱 Social Media

### Open Graph Tags

Already included in `<head>`:
```html
<meta property="og:title" content="LenKinVerse - Walk to Earn Web3 Game">
<meta property="og:description" content="Turn your steps into blockchain assets.">
<meta property="og:image" content="./assets/og-image.png">
```

**Create `og-image.png`:**
- Size: 1200×630px
- Include: Logo, tagline, key feature
- Text: Large and readable

### Twitter Card

Add to `<head>`:
```html
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="LenKinVerse">
<meta name="twitter:description" content="Walk. Discover. Own.">
<meta name="twitter:image" content="./assets/og-image.png">
```

---

## 🔒 Security

### CORS

Backend allows landing page origin:

```typescript
// backend/src/api/server.ts
app.use(cors({
    origin: process.env.CORS_ORIGIN || '*'
}));
```

Set in `.env`:
```
CORS_ORIGIN=https://lenkinverse.com
```

### Rate Limiting

Add to backend to prevent spam:

```typescript
import rateLimit from 'express-rate-limit';

const waitlistLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 signups per IP
    message: 'Too many signups, please try again later'
});

app.use('/api/waitlist', waitlistLimiter);
```

### Input Validation

Already implemented:
- Email format validation (frontend + backend)
- SQL injection protection (parameterized queries)
- XSS protection (no user input rendered)

---

## 📈 Analytics

### Google Analytics

Add to `<head>`:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

Events tracked in `js/script.js`:
- `waitlist_signup` - Email form submission

### Custom Events

Add more tracking:
```javascript
// Button clicks
gtag('event', 'click', {
    'event_category': 'navigation',
    'event_label': 'features_button'
});
```

---

## ✅ Checklist

Before launch:

**Content:**
- [ ] Update all placeholder text
- [ ] Add real images to `assets/`
- [ ] Create favicon.svg
- [ ] Create og-image.png (1200×630)
- [ ] Test all links

**Backend:**
- [ ] Run waitlist migration
- [ ] Test `/api/waitlist` endpoint
- [ ] Set CORS_ORIGIN
- [ ] Add rate limiting
- [ ] Enable HTTPS

**Deployment:**
- [ ] Deploy backend
- [ ] Deploy landing page
- [ ] Update API URL in script.js
- [ ] Test form submission
- [ ] Check mobile responsiveness

**SEO:**
- [ ] Add Google Analytics
- [ ] Submit sitemap
- [ ] Add meta descriptions
- [ ] Test social media previews

---

## 🐛 Troubleshooting

**Form not submitting?**
- Check browser console for errors
- Verify backend is running
- Check CORS settings
- Test API endpoint directly: `curl -X POST http://localhost:3000/api/waitlist -d '{"email":"test@example.com"}' -H "Content-Type: application/json"`

**Styles not loading?**
- Clear browser cache
- Check file paths are correct
- Ensure CSS file exists

**Database errors?**
- Run migration: `psql -f migrations/007_waitlist.sql`
- Check database connection in backend
- Verify table exists: `\dt waitlist`

---

## 📞 Support

Questions? Check the main project docs:
- [Main README](../README.md)
- [Backend Docs](../docs/backend/)
- [API Documentation](../docs/backend/INTEGRATION_COMPLETE.md)

---

**Built with ❤️ for LenKinVerse** 🎮✨
