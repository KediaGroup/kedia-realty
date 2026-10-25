-- Kedia Group CMS rebuild schema
-- WARNING: This script is intentionally destructive for the website CMS tables.
-- Run this only when you are ready to rebuild the Supabase project content model.
-- It does not delete Supabase Auth users, but it will remove admin profile rows,
-- projects, project images, project layouts, career roles, and applications.

create extension if not exists pgcrypto;

drop table if exists public.project_layouts cascade;
drop table if exists public.project_images cascade;
drop table if exists public.career_applications cascade;
drop table if exists public.career_roles cascade;
drop table if exists public.contact_leads cascade;
drop table if exists public.projects cascade;
drop table if exists public.admin_profiles cascade;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null default 'editor' check (role in ('owner', 'editor', 'viewer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  type text not null,
  status text not null,
  city text not null,
  region text not null,
  size_min_sq_yd numeric(10, 2) check (size_min_sq_yd >= 0),
  size_max_sq_yd numeric(10, 2) check (size_max_sq_yd >= 0),
  total_units integer not null check (total_units >= 0),
  rera_number text not null,
  launch_date text not null,
  price_label text not null,
  description text not null,
  amenities text[] not null default '{}',
  map_embed_url text,
  is_published boolean not null default false,
  is_featured boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint projects_size_range_check
    check (size_min_sq_yd is null or size_max_sq_yd is null or size_min_sq_yd <= size_max_sq_yd)
);

create table public.project_images (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  image_url text not null,
  alt_text text,
  is_cover boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index project_images_one_cover_idx
  on public.project_images (project_id)
  where is_cover = true;

create table public.project_layouts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text,
  type text,
  area text,
  image_url text not null,
  description text,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.career_roles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  department text not null,
  location text not null,
  employment_type text not null,
  summary text not null,
  responsibilities text[] not null default '{}',
  requirements text[] not null default '{}',
  is_open boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.career_applications (
  id uuid primary key default gen_random_uuid(),
  role_id uuid references public.career_roles(id) on delete set null,
  role_title text not null,
  candidate_name text not null,
  email text not null,
  phone text not null,
  city text not null default 'Not provided',
  experience text not null default 'Not provided',
  expected_salary text,
  resume_url text not null,
  portfolio_url text,
  message text not null,
  status text not null default 'New',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.contact_leads (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  phone text not null,
  message text not null,
  status text not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_admin_profiles_updated_at
before update on public.admin_profiles
for each row execute function public.set_updated_at();

create trigger set_projects_updated_at
before update on public.projects
for each row execute function public.set_updated_at();

create trigger set_project_images_updated_at
before update on public.project_images
for each row execute function public.set_updated_at();

create trigger set_project_layouts_updated_at
before update on public.project_layouts
for each row execute function public.set_updated_at();

create trigger set_career_roles_updated_at
before update on public.career_roles
for each row execute function public.set_updated_at();

create trigger set_career_applications_updated_at
before update on public.career_applications
for each row execute function public.set_updated_at();

create trigger set_contact_leads_updated_at
before update on public.contact_leads
for each row execute function public.set_updated_at();

create index projects_slug_idx on public.projects (slug);
create index projects_published_order_idx
  on public.projects (is_published, display_order, updated_at desc);
create index projects_featured_order_idx
  on public.projects (is_featured, is_published, display_order, updated_at desc);
create index projects_region_idx on public.projects (region);
create index projects_type_status_idx on public.projects (type, status);
create index project_images_project_order_idx
  on public.project_images (project_id, is_cover desc, display_order);
create index project_layouts_project_order_idx
  on public.project_layouts (project_id, display_order);
create index career_roles_open_created_idx
  on public.career_roles (is_open, created_at desc);
create index career_roles_slug_idx on public.career_roles (slug);
create index career_applications_created_idx
  on public.career_applications (created_at desc);
create index career_applications_role_idx
  on public.career_applications (role_id, created_at desc);
create index contact_leads_status_created_idx
  on public.contact_leads (status, created_at desc);

alter table public.admin_profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_images enable row level security;
alter table public.project_layouts enable row level security;
alter table public.career_roles enable row level security;
alter table public.career_applications enable row level security;
alter table public.contact_leads enable row level security;

create or replace function public.current_admin_role()
returns text
language sql
security definer
set search_path = public
as $$
  select role from public.admin_profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists(select 1 from public.admin_profiles where id = auth.uid());
$$;

create or replace function public.can_edit_content()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(public.current_admin_role() in ('owner', 'editor'), false);
$$;

create policy "Admins can read admin profiles"
on public.admin_profiles for select
to authenticated
using (public.is_admin());

create policy "Owners can manage admin profiles"
on public.admin_profiles for all
to authenticated
using (public.current_admin_role() = 'owner')
with check (public.current_admin_role() = 'owner');

create policy "Public can read published projects"
on public.projects for select
to anon, authenticated
using (is_published = true or public.is_admin());

create policy "Editors can insert projects"
on public.projects for insert
to authenticated
with check (public.can_edit_content());

create policy "Editors can update projects"
on public.projects for update
to authenticated
using (public.can_edit_content())
with check (public.can_edit_content());

create policy "Editors can delete projects"
on public.projects for delete
to authenticated
using (public.can_edit_content());

create policy "Public can read published project images"
on public.project_images for select
to anon, authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.projects
    where projects.id = project_images.project_id
      and projects.is_published = true
  )
);

create policy "Editors can insert project images"
on public.project_images for insert
to authenticated
with check (public.can_edit_content());

create policy "Editors can update project images"
on public.project_images for update
to authenticated
using (public.can_edit_content())
with check (public.can_edit_content());

create policy "Editors can replace project images"
on public.project_images for delete
to authenticated
using (public.can_edit_content());

create policy "Public can read published project layouts"
on public.project_layouts for select
to anon, authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.projects
    where projects.id = project_layouts.project_id
      and projects.is_published = true
  )
);

create policy "Editors can insert project layouts"
on public.project_layouts for insert
to authenticated
with check (public.can_edit_content());

create policy "Editors can update project layouts"
on public.project_layouts for update
to authenticated
using (public.can_edit_content())
with check (public.can_edit_content());

create policy "Editors can replace project layouts"
on public.project_layouts for delete
to authenticated
using (public.can_edit_content());

create policy "Public can read open career roles"
on public.career_roles for select
to anon, authenticated
using (is_open = true or public.is_admin());

create policy "Editors can insert career roles"
on public.career_roles for insert
to authenticated
with check (public.can_edit_content());

create policy "Editors can update career roles"
on public.career_roles for update
to authenticated
using (public.can_edit_content())
with check (public.can_edit_content());

create policy "Editors can delete career roles"
on public.career_roles for delete
to authenticated
using (public.can_edit_content());

create policy "Public can submit career applications"
on public.career_applications for insert
to anon, authenticated
with check (true);

create policy "Admins can read career applications"
on public.career_applications for select
to authenticated
using (public.is_admin());

create policy "Editors can update career applications"
on public.career_applications for update
to authenticated
using (public.can_edit_content())
with check (public.can_edit_content());

create policy "Editors can delete career applications"
on public.career_applications for delete
to authenticated
using (public.can_edit_content());

create policy "Public can submit contact leads"
on public.contact_leads for insert
to anon, authenticated
with check (true);

create policy "Admins can read contact leads"
on public.contact_leads for select
to authenticated
using (public.is_admin());

create policy "Editors can update contact leads"
on public.contact_leads for update
to authenticated
using (public.can_edit_content())
with check (public.can_edit_content());

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'project-images',
  'project-images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
) on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'career-resumes',
  'career-resumes',
  false,
  10485760,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
) on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read project images" on storage.objects;
create policy "Public can read project images"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'project-images');

drop policy if exists "Editors can upload project images" on storage.objects;
create policy "Editors can upload project images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'project-images'
  and public.can_edit_content()
);

drop policy if exists "Editors can update project images" on storage.objects;
create policy "Editors can update project images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'project-images'
  and public.can_edit_content()
)
with check (
  bucket_id = 'project-images'
  and public.can_edit_content()
);

drop policy if exists "Editors can delete project images" on storage.objects;
create policy "Editors can delete project images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'project-images'
  and public.can_edit_content()
);

drop policy if exists "Applicants can upload career resumes" on storage.objects;
create policy "Applicants can upload career resumes"
on storage.objects for insert
to anon, authenticated
with check (bucket_id = 'career-resumes');

drop policy if exists "Admins can read career resumes" on storage.objects;
create policy "Admins can read career resumes"
on storage.objects for select
to authenticated
using (
  bucket_id = 'career-resumes'
  and public.is_admin()
);

drop policy if exists "Editors can delete career resumes" on storage.objects;
create policy "Editors can delete career resumes"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'career-resumes'
  and public.can_edit_content()
);

-- Seed helper: after creating a Supabase Auth user, add them as an owner:
-- insert into public.admin_profiles (id, email, role)
-- values ('AUTH_USER_UUID', 'admin@example.com', 'owner');

-- Optional starter content matching the current website fallback projects.
insert into public.projects (
  title, slug, type, status, city, region, size_min_sq_yd, size_max_sq_yd, total_units,
  rera_number, launch_date, price_label, description, amenities,
  map_embed_url, is_published, is_featured, display_order
) values
(
  'Kedia City', 'kedia-city', 'Residential Township', 'Underway',
  'Jaipur', 'Ajmer Road', 100, 267, 1250, 'RAJ/P/2025/3184', 'March 2025',
  'Plots from ₹38 Lakh',
  'A planned residential township designed around broad internal roads, everyday conveniences, landscaped open spaces, and a clear development framework for long-term value creation.',
  array['Clubhouse','Children''s Play Area','Jogging Track','Temple Plaza','Gated Entry','Rainwater Harvesting'],
  'https://www.google.com/maps?q=Ajmer%20Road%20Jaipur%20Rajasthan&output=embed',
  true, true, 10
),
(
  'Kedia Square', 'kedia-square', 'Commercial', 'Ready',
  'Jaipur', 'Vaishali Nagar', 47, 233, 186, 'RAJ/P/2023/2461', 'August 2023',
  'Commercial units from ₹52 Lakh',
  'A high-visibility commercial development planned for retail, boutique offices, service-led businesses, and neighborhood-scale customer movement.',
  array['Basement Parking','High-Speed Elevators','Power Backup','CCTV Surveillance','Fire Safety Systems','Common Washrooms'],
  'https://www.google.com/maps?q=Vaishali%20Nagar%20Jaipur%20Rajasthan&output=embed',
  true, true, 20
),
(
  'Kedia Greens Villas', 'kedia-greens-villas', 'Villas', 'Underway',
  'Udaipur', 'Nathdwara Road', 244, 400, 96, 'RAJ/P/2025/3262', 'June 2025',
  'Villas from ₹1.35 Cr',
  'A villa community shaped around controlled density, landscaped streets, and contemporary residential formats for families seeking independent living within a managed development.',
  array['Club Lounge','Recreation Deck','Indoor Games','Fitness Studio','Party Lawn','Visitor Parking'],
  null,
  true, true, 30
),
(
  'Kedia Heights', 'kedia-heights', 'Apartments', 'Completed',
  'Jaipur', 'Mansarovar Extension', 117, 206, 420, 'RAJ/P/2021/1678', 'January 2021',
  'Apartments from ₹64 Lakh',
  'A completed apartment development with efficient unit planning, established amenities, and strong neighborhood connectivity for everyday urban living.',
  array['Community Hall','Fitness Studio','Children''s Play Area','Landscaped Gardens','Power Backup','Controlled Access'],
  'https://www.google.com/maps?q=Mansarovar%20Extension%20Jaipur%20Rajasthan&output=embed',
  true, false, 40
),
(
  'Kedia Agro Farms', 'kedia-agro-farms', 'Farmhouses', 'Ready',
  'Alwar', 'Sariska Road', 667, 1333, 72, 'RAJ/P/2024/2875', 'November 2024',
  'Farm plots from ₹42 Lakh',
  'A managed farmhouse development planned for weekend living, agricultural leisure, and land ownership with organized infrastructure and access.',
  array['Gated Entry','Wide Internal Roads','Water Provision','Plantation Zones','Common Greens','Maintenance Support'],
  null,
  true, false, 50
),
(
  'Kedia Industrial Park', 'kedia-industrial-park', 'Industrial Township', 'Underway',
  'Neemrana', 'NH-48 Corridor', 1111, 8889, 214, 'RAJ/P/2025/3311', 'September 2025',
  'Industrial plots on request',
  'An industrial township planned for warehousing, light manufacturing, logistics, and ancillary commercial use along a high-growth industrial corridor.',
  array['Wide Internal Roads','Power Infrastructure','Drainage Planning','Gated Entry','Weighbridge Provision','Admin Support Zone'],
  'https://www.google.com/maps?q=Neemrana%20Rajasthan%20NH%2048&output=embed',
  true, false, 60
);

insert into public.project_images (
  project_id, image_url, alt_text, is_cover, display_order
)
select p.id, i.image_url, i.alt_text, i.is_cover, i.display_order
from public.projects p
join (
  values
  ('kedia-city','https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1600&q=80','Kedia City project image',true,10),
  ('kedia-city','https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1400&q=80','Kedia City gallery image',false,20),
  ('kedia-city','https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1400&q=80','Kedia City gallery image',false,30),
  ('kedia-square','https://images.unsplash.com/photo-1497366811353-6870744d04b2?auto=format&fit=crop&w=1600&q=80','Kedia Square project image',true,10),
  ('kedia-greens-villas','https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?auto=format&fit=crop&w=1600&q=80','Kedia Greens Villas project image',true,10),
  ('kedia-heights','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1600&q=80','Kedia Heights project image',true,10),
  ('kedia-agro-farms','https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1600&q=80','Kedia Agro Farms project image',true,10),
  ('kedia-industrial-park','https://images.unsplash.com/photo-1581094794329-c8112a89af12?auto=format&fit=crop&w=1600&q=80','Kedia Industrial Park project image',true,10)
) as i(slug, image_url, alt_text, is_cover, display_order)
on p.slug = i.slug;

insert into public.project_layouts (
  project_id, title, type, area, image_url, description, display_order
)
select p.id, l.title, l.type, l.area, l.image_url, l.description, l.display_order
from public.projects p
join (
  values
  ('kedia-city','Residential Plot','Plotted Development','900 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Compact residential plot planned for efficient frontage, service access, and future-ready family living.',10),
  ('kedia-city','Premium Plot','Plotted Development','1,800 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Larger plot format positioned near open spaces and planned community amenities.',20),
  ('kedia-city','Garden Apartment','Apartments','1,250 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Apartment layout designed for natural light, efficient circulation, and family comfort.',30),
  ('kedia-square','Retail Frontage Unit','Retail','520 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Street-facing retail unit with clear frontage and efficient customer entry.',10),
  ('kedia-square','Corporate Office','Office','1,450 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Flexible office plan suitable for professional services and growing teams.',20),
  ('kedia-greens-villas','Courtyard Villa','3 BHK Villa','2,200 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Independent villa format with a compact courtyard and practical family zoning.',10),
  ('kedia-greens-villas','Premium Villa','4 BHK Villa','3,600 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Expanded villa plan with larger living areas, terraces, and staff/service provision.',20),
  ('kedia-heights','Efficient Residence','2 BHK Apartment','1,050 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','2 BHK apartment with clear separation between living and family zones.',10),
  ('kedia-heights','Family Residence','3 BHK Apartment','1,650 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','3 BHK plan with larger living space and practical storage provision.',20),
  ('kedia-agro-farms','Farm Plot','Farmhouse Plot','6,000 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Entry farm plot with flexible siting for landscape, leisure, and built form.',10),
  ('kedia-agro-farms','Premium Farm Plot','Farmhouse Plot','12,000 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Larger plot format for expanded landscape, open-air recreation, and weekend use.',20),
  ('kedia-industrial-park','Logistics Plot','Industrial Plot','20,000 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Mid-sized industrial plot suitable for warehousing and logistics-led operations.',10),
  ('kedia-industrial-park','Manufacturing Plot','Industrial Plot','50,000 sq ft','https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80','Large industrial format with planning flexibility for production and service movement.',20)
) as l(slug, title, type, area, image_url, description, display_order)
on p.slug = l.slug;
