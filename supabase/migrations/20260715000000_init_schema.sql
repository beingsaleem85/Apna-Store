-- 1. یوزر رولز کے لیے انم (Enum) ٹائپ بنانا
CREATE TYPE user_role AS ENUM ('buyer', 'seller', 'admin');

-- 2. پروفائلز ٹیبل بنانا جو سپابیس کی اپنی ایتھنٹیکیشن (auth.users) سے جڑا ہوگا
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  full_name TEXT,
  phone_number TEXT,
  role user_role DEFAULT 'buyer'::user_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. سیلرز کے اسٹورز کی معلومات کے لیے ٹیبل
CREATE TABLE public.sellers (
  id UUID REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
  shop_name TEXT NOT NULL,
  shop_logo TEXT,
  is_approved BOOLEAN DEFAULT FALSE NOT NULL,
  commission_rate DECIMAL(5,2) DEFAULT 10.00 NOT NULL, -- سپر ایڈمن کی کمیشن فیصد (پہلے سے طے شدہ 10%)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 4. رئیل ٹائم (Real-time) اور سیکیورٹی پالیسیز (RLS) کو فعال کرنا
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sellers ENABLE ROW LEVEL SECURITY;

-- 5. آٹو پروفائل بنانے کے لیے ایک فنکشن جو نئے سائن اپ ہونے والے صارف کا پروفائل خود بخود بنا دے گا
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', 'نیا صارف'),
    COALESCE((new.raw_user_meta_data->>'role')::user_role, 'buyer'::user_role)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. ٹرگر سیٹ کرنا جو سائن اپ پر فنکشن چلائے گا
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
