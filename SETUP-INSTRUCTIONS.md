# Business Flashcards - Setup Instructions

This guide will walk you through setting up your Business Flashcards website with user authentication, subscription tracking, and payment integration.

## Overview

Your website consists of:
- **Landing page** (index.html) - Sales/marketing page
- **Login/Signup pages** - User authentication
- **Payment page** - Payhip integration
- **App page** - Protected flashcards (requires login + active subscription)

## Tech Stack

- **Frontend**: HTML, CSS, JavaScript
- **Authentication & Database**: Supabase (free tier)
- **Payments**: Payhip with Flutterwave (for South Africa)
- **Hosting**: Vercel (free tier)

---

## Step 1: Set Up Supabase

### 1.1 Create a Supabase Account

1. Go to [supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign up with GitHub or email
4. Create a new project:
   - **Name**: `business-flashcards`
   - **Database Password**: Choose a strong password (save this!)
   - **Region**: Choose the closest to your users
5. Wait for the project to be created (2-3 minutes)

### 1.2 Get Your API Keys

1. In your Supabase dashboard, click **Settings** (gear icon)
2. Click **API** in the sidebar
3. Copy these two values:
   - **Project URL** (e.g., `https://abcdefgh.supabase.co`)
   - **anon/public** key (starts with `eyJ...`)

### 1.3 Update Your Website Files

Open each of these files and replace the placeholder values:

**Files to update:**
- `login.html`
- `signup.html`
- `payment.html`
- `app.html`
- `forgot-password.html`

Find these lines and replace with your actual values:

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';        // Replace with your Project URL
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'; // Replace with your anon key
```

### 1.4 Create the Subscriptions Table

1. In Supabase dashboard, click **SQL Editor**
2. Click **New query**
3. Paste this SQL and click **Run**:

```sql
-- Create subscriptions table
CREATE TABLE subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    email TEXT NOT NULL,
    plan TEXT DEFAULT 'yearly',
    amount DECIMAL(10,2) DEFAULT 20.00,
    currency TEXT DEFAULT 'USD',
    status TEXT DEFAULT 'active',
    payment_provider TEXT DEFAULT 'payhip',
    payment_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(user_id)
);

-- Enable Row Level Security
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own subscription
CREATE POLICY "Users can view own subscription"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Allow service role to insert/update (for webhooks)
CREATE POLICY "Service role can manage subscriptions"
    ON subscriptions FOR ALL
    USING (auth.role() = 'service_role');

-- Create index for faster lookups
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_expires_at ON subscriptions(expires_at);
```

### 1.5 Enable Email Authentication

1. In Supabase dashboard, go to **Authentication** → **Providers**
2. Make sure **Email** is enabled
3. Go to **Authentication** → **Email Templates**
4. Customize the templates if desired (optional)

---

## Step 2: Set Up Payhip

### 2.1 Create a Payhip Account

1. Go to [payhip.com](https://payhip.com) and sign up
2. Complete your profile and payment settings

### 2.2 Connect Flutterwave (for South African payouts)

1. In Payhip, go to **Settings** → **Payment Settings**
2. Choose **Flutterwave** as your payment processor
3. Create a Flutterwave account at [flutterwave.com](https://flutterwave.com)
4. Connect your South African bank account in Flutterwave
5. Link Flutterwave to Payhip

### 2.3 Create Your Product

1. In Payhip, click **Add Product**
2. Choose **Digital Product** or **Membership**
3. Set up:
   - **Name**: Business Flashcards - 1 Year Access
   - **Price**: $20.00
   - **Description**: Full access to 378 Business Studies flashcards for 12 months

### 2.4 Get Your Product Link

1. Go to your product page
2. Copy the product URL (e.g., `https://payhip.com/b/XXXXX`)
3. Update `payment.html`:

```html
<a href="https://payhip.com/b/YOUR_PRODUCT_ID"
   class="btn btn-primary payhip-button"
   data-payhip-product-link="YOUR_PRODUCT_ID">
```

### 2.5 Set Up Webhook (for automatic activation)

1. In Payhip, go to **Settings** → **Webhooks**
2. Add a new webhook:
   - **URL**: `https://your-domain.com/api/payhip-webhook`
   - **Events**: Select "Sale completed"
3. Copy the **Webhook Secret** for later

---

## Step 3: Set Up Vercel (Hosting)

### 3.1 Create a Vercel Account

1. Go to [vercel.com](https://vercel.com) and sign up
2. Connect your GitHub account (recommended)

### 3.2 Deploy Your Site

**Option A: GitHub (Recommended)**

1. Create a new GitHub repository
2. Upload all your files to the repository
3. In Vercel, click **Import Project**
4. Select your GitHub repository
5. Click **Deploy**

**Option B: Direct Upload**

1. In Vercel, click **Add New** → **Project**
2. Choose **Upload** and drag your files
3. Click **Deploy**

### 3.3 Connect Your Domain

1. Purchase domain from GoDaddy (as planned)
2. In Vercel project settings, go to **Domains**
3. Add your custom domain
4. Update DNS settings in GoDaddy:
   - Add CNAME record pointing to `cname.vercel-dns.com`

---

## Step 4: Create Webhook Handler

To automatically activate subscriptions after payment, create a serverless function.

### 4.1 Create API Folder

In your project, create: `api/payhip-webhook.js`

```javascript
// api/payhip-webhook.js
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

export default async function handler(req, res) {
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
        const { buyer_email, product_id, sale_id } = req.body;

        // Find user by email
        const { data: users, error: userError } = await supabase
            .from('auth.users')
            .select('id')
            .eq('email', buyer_email)
            .single();

        if (userError || !users) {
            // User hasn't signed up yet - store pending activation
            console.log('User not found, storing pending activation');
            return res.status(200).json({ status: 'pending' });
        }

        // Calculate expiry (1 year from now)
        const expiresAt = new Date();
        expiresAt.setFullYear(expiresAt.getFullYear() + 1);

        // Create or update subscription
        const { error: subError } = await supabase
            .from('subscriptions')
            .upsert({
                user_id: users.id,
                email: buyer_email,
                payment_id: sale_id,
                payment_provider: 'payhip',
                status: 'active',
                expires_at: expiresAt.toISOString()
            }, {
                onConflict: 'user_id'
            });

        if (subError) throw subError;

        return res.status(200).json({ status: 'activated' });

    } catch (error) {
        console.error('Webhook error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
}
```

### 4.2 Add Environment Variables in Vercel

1. Go to your Vercel project → **Settings** → **Environment Variables**
2. Add:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SERVICE_KEY`: Your Supabase **service_role** key (from API settings)

---

## Step 5: Add Flashcard Data

### 5.1 Create Flashcard Data File

Create `flashcard-data.js` in your project root with your flashcard data:

```javascript
// flashcard-data.js
const flashcardData = [
    {
        id: 1,
        unit: 1,
        type: 'term',
        question: 'What is Price Elasticity of Demand (PED)?',
        answer: '<strong>PED</strong> measures how responsive quantity demanded is to a change in price.<br><br><strong>Formula:</strong> % change in Qd ÷ % change in P'
    },
    // ... add all 378 cards
];
```

You'll need to extract the flashcard data from your comprehensive HTML file.

---

## Step 6: Testing

### 6.1 Test the Authentication Flow

1. Go to your deployed site
2. Click "Sign Up"
3. Create a test account
4. Verify you receive a confirmation email
5. Test login/logout

### 6.2 Test the Payment Flow

1. In Payhip, enable **Test Mode**
2. Complete a test purchase
3. Verify the webhook activates the subscription
4. Check that the user can access the flashcards

---

## Maintenance

### Checking Subscriptions

In Supabase SQL Editor, run:

```sql
-- View all active subscriptions
SELECT * FROM subscriptions WHERE status = 'active';

-- View expiring soon (next 30 days)
SELECT * FROM subscriptions
WHERE expires_at < NOW() + INTERVAL '30 days'
AND expires_at > NOW();

-- View expired subscriptions
SELECT * FROM subscriptions WHERE expires_at < NOW();
```

### Manually Activating a Subscription

If needed, you can manually activate a subscription:

```sql
-- Replace with actual user_id and email
INSERT INTO subscriptions (user_id, email, expires_at)
VALUES (
    'user-uuid-here',
    'user@email.com',
    NOW() + INTERVAL '1 year'
);
```

---

## Cost Summary

| Service | Monthly Cost |
|---------|--------------|
| Supabase | Free (up to 500MB, 50K users) |
| Vercel | Free (100GB bandwidth) |
| Payhip | ~5% per transaction |
| Flutterwave | ~3% per transaction |
| GoDaddy Domain | ~$12/year |

**Total monthly cost**: Essentially free until you scale significantly!

---

## Support

If you run into issues:

1. Check Supabase logs: Dashboard → Logs
2. Check Vercel deployment logs
3. Test webhooks with [webhook.site](https://webhook.site)
4. Verify environment variables are set correctly

Good luck with your Business Flashcards website! 🎓
