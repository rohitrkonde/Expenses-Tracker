# Couple Cashflow — free setup

## 1. Create the free Supabase project
Create a Supabase project and open SQL Editor.

## 2. Run the database schema
Copy all of schema.sql into the SQL Editor and run it once.

## 3. Get the browser-safe credentials
From Supabase project settings, copy:
- Project URL
- Publishable/anon key

Do not put a service-role/secret key in this app.

## 4. Open the GitHub Pages site
The app already contains the browser-safe Supabase Project URL and publishable/anon key, so the login page does not ask for database configuration.

## 5. Create the three fixed household accounts
The login UI uses the three application usernames: `rohit`, `rohit & kavita`, and `kavita`. The corresponding Supabase Auth users must exist before those logins can succeed. Do not put a Supabase service-role/secret key in the browser; account provisioning should be done through Supabase Auth/admin tooling or a server-side Edge Function.

## Security
All financial tables use Supabase Row Level Security and household membership checks. Keep RLS enabled.

## Included
Dashboard, transactions, accounts, budgets, recurring bills, savings goals, settlements, reports/CSV export, household members, INR/multi-currency display, mobile UI, and GitHub Pages deployment workflow.
