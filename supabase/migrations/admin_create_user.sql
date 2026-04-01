-- ─────────────────────────────────────────────────────────────────────────────
-- admin_create_user — creates a new auth user + profile from the admin panel
-- Run this in Supabase SQL Editor (it requires SECURITY DEFINER to write auth.users)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_create_user(
  p_email      text,
  p_name       text,
  p_university text DEFAULT NULL,
  p_role       text DEFAULT 'user'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_new_uid     uuid := gen_random_uuid();
BEGIN
  -- ── Authorization check ─────────────────────────────────────────────────
  SELECT role INTO v_caller_role
  FROM profiles
  WHERE id = auth.uid();

  IF v_caller_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'Unauthorized: only admins can create users';
  END IF;

  -- ── Validate inputs ─────────────────────────────────────────────────────
  IF p_email IS NULL OR trim(p_email) = '' THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'Name is required';
  END IF;

  -- Check email not already taken
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = lower(trim(p_email))) THEN
    RAISE EXCEPTION 'A user with this email already exists';
  END IF;

  -- ── Insert into auth.users (no password — user must use "forgot password") ─
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    role,
    aud,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  ) VALUES (
    v_new_uid,
    '00000000-0000-0000-0000-000000000000',
    lower(trim(p_email)),
    '',                                           -- empty password → must reset
    now(),                                        -- pre-confirm email
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('name', p_name),
    false,
    'authenticated',
    'authenticated',
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

  -- ── The profile trigger should auto-create the profile row.
  -- But in case it doesn't (or needs extra fields), upsert it:
  INSERT INTO profiles (
    id, email, name, university, role,
    onboarding_completed, is_banned, created_at, updated_at
  )
  VALUES (
    v_new_uid,
    lower(trim(p_email)),
    p_name,
    p_university,
    COALESCE(p_role, 'user'),
    false,
    false,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
    SET name       = EXCLUDED.name,
        university = EXCLUDED.university,
        role       = EXCLUDED.role,
        updated_at = now();

  RETURN jsonb_build_object(
    'id',    v_new_uid,
    'email', lower(trim(p_email)),
    'name',  p_name,
    'role',  COALESCE(p_role, 'user')
  );
END;
$$;

-- Grant execute to authenticated users (RLS inside checks admin role)
GRANT EXECUTE ON FUNCTION admin_create_user(text, text, text, text) TO authenticated;
