# 🚀 Landing Page Deployment Guide

Quick guide to deploy the LenKinVerse landing page and waitlist.

---

## ✅ What's Ready

### Frontend
- ✅ Responsive HTML landing page
- ✅ Modern CSS with dark theme
- ✅ JavaScript waitlist form with validation
- ✅ Smooth scroll & animations
- ✅ Mobile-optimized

### Backend
- ✅ Waitlist API endpoint (`/api/waitlist`)
- ✅ PostgreSQL migration (007_waitlist.sql)
- ✅ Email validation & duplicate prevention
- ✅ Stats endpoint for admin

---

## 🚀 Quick Deploy (5 minutes)

### Step 1: Setup Database

```bash
# Run waitlist migration
cd backend
psql -U postgres -d lenkinverse -f src/db/migrations/007_waitlist.sql

# Verify table created
psql -U postgres -d lenkinverse -c "\d waitlist"
```

### Step 2: Start Backend

```bash
cd backend
npm install
npm run dev

# Backend runs on http://localhost:3000
```

### Step 3: Test Landing Page

```bash
cd landing-page

# Option A: Open directly
open index.html

# Option B: Use local server
python3 -m http.server 8000
# Visit http://localhost:8000
```

### Step 4: Test Waitlist

1. Visit landing page
2. Scroll to "Join Waitlist" section
3. Enter email: `test@example.com`
4. Click "Join Waitlist"
5. Should see: "🎉 Success! You're on the waitlist."

**Verify in database:**
```bash
psql -U postgres -d lenkinverse -c "SELECT * FROM waitlist;"
```

---

## 🌐 Production Deployment

### Option 1: Vercel (Recommended for Frontend)

**Deploy landing page:**
```bash
npm install -g vercel
cd landing-page
vercel

# Follow prompts
# Gets URL like: https://lenkinverse.vercel.app
```

**Update API endpoint in `js/script.js`:**
```javascript
const response = await fetch('https://your-backend-url.com/api/waitlist', {
    method: 'POST',
    // ...
});
```

### Option 2: Same Server (Simplest)

**Serve landing page from backend:**

1. Copy landing page to backend:
```bash
cp -r landing-page backend/public
```

2. Add static file serving in `backend/src/api/server.ts`:
```typescript
import path from 'path';

// After other middleware
app.use(express.static(path.join(__dirname, '../../public')));
```

3. Deploy backend to Railway/Heroku:
```bash
cd backend
git add .
git commit -m "Add landing page"
git push heroku main
```

Now landing page is at: `https://your-backend.com/`

### Option 3: Netlify

1. Push to GitHub
2. Connect Netlify to repository
3. Build settings:
   - Base directory: `landing-page`
   - Publish directory: `.` (root)
4. Add environment variable:
   - `API_URL` = your backend URL
5. Deploy!

---

## 🔧 Configuration

### Backend CORS

Allow landing page origin in `backend/.env`:
```env
CORS_ORIGIN=https://lenkinverse.vercel.app
```

Or in code (`backend/src/api/server.ts`):
```typescript
app.use(cors({
    origin: [
        'http://localhost:8000',
        'https://lenkinverse.vercel.app',
        'https://lenkinverse.com'
    ]
}));
```

### API URL

Update in `landing-page/js/script.js`:
```javascript
// Development
const API_URL = 'http://localhost:3000';

// Production
const API_URL = 'https://api.lenkinverse.com';

// Use in fetch
const response = await fetch(`${API_URL}/api/waitlist`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email })
});
```

---

## 📊 Monitor Waitlist

### View Signups

```bash
# Total signups
psql -U postgres -d lenkinverse -c "SELECT COUNT(*) FROM waitlist;"

# Recent signups
psql -U postgres -d lenkinverse -c "SELECT email, signed_up_at FROM waitlist ORDER BY signed_up_at DESC LIMIT 10;"

# Signups by source
psql -U postgres -d lenkinverse -c "SELECT source, COUNT(*) FROM waitlist GROUP BY source;"
```

### API Stats

```bash
# Get stats via API
curl http://localhost:3000/api/waitlist/stats

# Response:
{
    "success": true,
    "data": {
        "total_signups": "123",
        "signups_today": "45",
        "signups_week": "67",
        "first_signup": "2025-01-01T00:00:00.000Z",
        "latest_signup": "2025-11-19T10:30:00.000Z"
    }
}
```

### Export Emails

```bash
# Export to CSV
psql -U postgres -d lenkinverse -c "\COPY (SELECT email, signed_up_at, source FROM waitlist ORDER BY signed_up_at) TO 'waitlist.csv' CSV HEADER"

# Now you have waitlist.csv for email campaigns
```

---

## 📧 Email Notifications

### Setup (TODO)

Add email service integration:

**Option A: SendGrid**
```bash
npm install @sendgrid/mail
```

```typescript
// backend/src/services/email.ts
import sgMail from '@sendgrid/mail';

sgMail.setApiKey(process.env.SENDGRID_API_KEY!);

export async function sendWelcomeEmail(email: string) {
    await sgMail.send({
        to: email,
        from: 'team@lenkinverse.com',
        subject: 'Welcome to LenKinVerse Waitlist!',
        html: `
            <h1>You're on the list! 🎉</h1>
            <p>Thanks for joining the LenKinVerse waitlist...</p>
        `
    });
}
```

**Option B: Mailgun**
```bash
npm install mailgun-js
```

**Add to waitlist route:**
```typescript
// In backend/src/routes/waitlist.ts
import { sendWelcomeEmail } from '../services/email';

// After successful signup
await sendWelcomeEmail(normalizedEmail);
```

---

## 🔒 Security Checklist

- [x] Email validation (frontend + backend)
- [x] SQL injection prevention (parameterized queries)
- [x] Duplicate email prevention
- [ ] Rate limiting (add with `express-rate-limit`)
- [ ] CAPTCHA (add reCAPTCHA for production)
- [ ] HTTPS only (configure in deployment)
- [ ] CORS properly configured
- [ ] Environment variables secured

### Add Rate Limiting

```bash
npm install express-rate-limit
```

```typescript
// backend/src/api/server.ts
import rateLimit from 'express-rate-limit';

const waitlistLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // Max 5 signups per IP
    message: 'Too many signups, please try again later'
});

app.use('/api/waitlist', waitlistLimiter, waitlistRouter);
```

---

## 📈 Analytics

### Google Analytics

1. Create GA4 property at https://analytics.google.com
2. Get tracking ID (G-XXXXXXXXXX)
3. Add to `landing-page/index.html` `<head>`:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

### Track Events

Already implemented in `js/script.js`:
- `waitlist_signup` - Fires when email submitted

Add more:
```javascript
// Track feature clicks
document.querySelectorAll('.feature-card').forEach(card => {
    card.addEventListener('click', () => {
        gtag('event', 'feature_view', {
            'event_category': 'engagement',
            'event_label': card.querySelector('.feature-title').textContent
        });
    });
});
```

---

## 🎨 Customization

### Update Colors

Edit `landing-page/css/style.css`:
```css
:root {
    --primary: #8B5CF6;      /* Purple - change to your brand */
    --secondary: #10B981;    /* Green */
    --background: #0F172A;   /* Dark blue */
}
```

### Add Logo

1. Create logo image: `landing-page/assets/logo.png`
2. Update navigation in `index.html`:

```html
<div class="logo">
    <img src="./assets/logo.png" alt="LenKinVerse" height="40">
    <span class="logo-text">LenKinVerse</span>
</div>
```

### Update Social Links

In `index.html` footer section:
```html
<a href="https://discord.gg/lenkinverse" target="_blank">Discord</a>
<a href="https://twitter.com/lenkinverse" target="_blank">Twitter</a>
```

---

## ✅ Pre-Launch Checklist

**Content:**
- [ ] Proofread all text
- [ ] Update placeholder links
- [ ] Add real social media URLs
- [ ] Create logo/favicon
- [ ] Create OG image (1200×630px)

**Technical:**
- [ ] Run database migration
- [ ] Test form submission
- [ ] Test on mobile devices
- [ ] Test in different browsers
- [ ] Check page speed (Lighthouse)

**Deployment:**
- [ ] Deploy backend
- [ ] Deploy landing page
- [ ] Update API URL in frontend
- [ ] Configure CORS
- [ ] Enable HTTPS
- [ ] Add rate limiting

**Marketing:**
- [ ] Setup Google Analytics
- [ ] Create email templates
- [ ] Prepare launch posts
- [ ] Test social media previews

---

## 🐛 Common Issues

**"Unable to connect" error:**
- Backend not running
- Wrong API URL in script.js
- CORS blocking request

**"Already on waitlist" for new email:**
- Database has that email
- Check: `SELECT * FROM waitlist WHERE email = 'test@example.com';`
- Delete test data: `DELETE FROM waitlist WHERE email LIKE '%@test.com';`

**Styles broken on mobile:**
- Clear browser cache
- Check viewport meta tag exists
- Test in device simulator

**Form not submitting:**
- Check browser console for errors
- Verify backend endpoint: `curl -X POST http://localhost:3000/api/waitlist -d '{"email":"test@test.com"}' -H "Content-Type: application/json"`
- Check database connection

---

## 📞 Support

Questions? Check:
- [Landing Page README](README.md)
- [Backend Docs](../docs/backend/)
- [Main Project README](../README.md)

---

**Your landing page is ready to collect early access signups! 🚀**

Deploy, share, and start building your community!
