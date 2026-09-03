-- ==========================================
-- FCM TOKEN MANAGEMENT
-- ==========================================

CREATE TABLE public.fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL, -- 'android', 'ios', 'web'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Users can insert their own tokens
CREATE POLICY "Users can insert own token" ON public.fcm_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens (e.g., token refresh)
CREATE POLICY "Users can update own token" ON public.fcm_tokens
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own tokens (e.g., logout)
CREATE POLICY "Users can delete own token" ON public.fcm_tokens
    FOR DELETE USING (auth.uid() = user_id);

-- Admin/TPO can view all tokens (needed to trigger mass pushes later)
CREATE POLICY "Admin/TPO view all tokens" ON public.fcm_tokens
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );