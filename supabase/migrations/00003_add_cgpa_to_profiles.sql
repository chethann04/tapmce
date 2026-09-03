-- Add CGPA field to profiles for eligibility checking
ALTER TABLE public.profiles 
ADD COLUMN cgpa DECIMAL(3, 2) DEFAULT 0.00;

-- Update RLS policy to allow users to update their own CGPA
-- (They need to input their academic data)
CREATE POLICY "Users can update own CGPA" ON public.profiles
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);