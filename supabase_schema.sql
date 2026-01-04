-- تمكين إضافة UUID
create extension if not exists "uuid-ossp";

-------------------------------------------------------------------------
-- 1. جدول الملف الشخصي (Profiles)
-- يربط بيانات المستخدم بجدول auth.users الخاص بـ Supabase
-------------------------------------------------------------------------
create table public.profiles (
  id uuid references auth.users not null primary key,
  email text,
  display_name text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- تمكين الحماية (RLS)
alter table public.profiles enable row level security;

-- سياسات الأمان
create policy "Users can view own profile" on profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);

-------------------------------------------------------------------------
-- 2. جدول النفقات (Expenses)
-------------------------------------------------------------------------
create table public.expenses (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null,
  category text not null,
  amount numeric not null,
  notes text,
  expense_date timestamp with time zone not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- تمكين الحماية (RLS)
alter table public.expenses enable row level security;

-- سياسات الأمان: المستخدم يرى ويعدل بياناته فقط
create policy "Users can CRUD own expenses" on expenses 
  for all using (auth.uid() = user_id);

-------------------------------------------------------------------------
-- 3. جدول الميزانيات (Budgets)
-------------------------------------------------------------------------
create table public.budgets (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null,
  category text not null,
  amount numeric not null,
  month integer not null,
  year integer not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- تمكين الحماية (RLS)
alter table public.budgets enable row level security;

-- سياسات الأمان: المستخدم يرى ويعدل بياناته فقط
create policy "Users can CRUD own budgets" on budgets 
  for all using (auth.uid() = user_id);

-------------------------------------------------------------------------
-- 4. إعداد Trigger لإنشاء Profile تلقائياً عند التسجيل
-------------------------------------------------------------------------
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, new.raw_user_meta_data->>'display_name');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
