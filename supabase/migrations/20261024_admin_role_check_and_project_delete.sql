-- admin_profiles.role was free text, so a profile saved as 'admin' passed
-- is_admin() (could sign in) but failed can_edit_content() (every project
-- insert and image upload was rejected by RLS). Normalise unknown roles to
-- 'editor' and pin the column to the roles the app understands.

update public.admin_profiles
set role = 'editor'
where role not in ('owner', 'editor', 'viewer');

alter table public.admin_profiles
  drop constraint if exists admin_profiles_role_check,
  add constraint admin_profiles_role_check
    check (role in ('owner', 'editor', 'viewer'));

-- createProject inserts the project row, then its images and layouts. If the
-- second step fails, the app deletes the half-created project so the admin can
-- retry without hitting the unique slug constraint. That needs a delete policy.

drop policy if exists "Editors can delete projects" on public.projects;
create policy "Editors can delete projects"
on public.projects for delete
to authenticated
using (public.can_edit_content());
