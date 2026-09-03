-- Add dob and gender columns to profiles table
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS dob DATE,
  ADD COLUMN IF NOT EXISTS gender TEXT;
