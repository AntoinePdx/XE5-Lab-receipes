-- Fuji X-E5 Recipes - Supabase setup
-- Run this in Supabase SQL Editor.
-- This version allows public CRUD with the anon key so the single HTML app can add/edit/delete.
-- If you share the site publicly, add Supabase Auth before storing private recipes.

create extension if not exists pgcrypto;

create table if not exists public.film_recipes (
    id text primary key default gen_random_uuid()::text,
    name text not null,
    sort_order integer not null default 0,
    simulation text,
    preset text,
    comment text,
    dynamic_range text,
    d_range_priority text,
    white_balance text,
    expo_compensation text,
    shift_red text,
    shift_blue text,
    highlights text,
    shadows text,
    color text,
    sharpness text,
    clarity text,
    high_iso_nr text,
    grain_effect text,
    grain_size text,
    color_chrome_effect text,
    color_chrome_fx_blue text,
    smooth_skin_effect text,
    rating text,
    favorite boolean not null default false,
    image_urls text[] not null default '{}',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.film_recipes
add column if not exists sort_order integer not null default 0;

create index if not exists film_recipes_name_idx on public.film_recipes (name);
create index if not exists film_recipes_simulation_idx on public.film_recipes (simulation);
create index if not exists film_recipes_favorite_idx on public.film_recipes (favorite);
create index if not exists film_recipes_sort_order_idx on public.film_recipes (sort_order);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists film_recipes_set_updated_at on public.film_recipes;
create trigger film_recipes_set_updated_at
before update on public.film_recipes
for each row
execute function public.set_updated_at();

create or replace function public.clear_duplicate_preset_slot()
returns trigger
language plpgsql
as $$
begin
    if new.preset in ('FS1', 'FS2', 'FS3') then
        update public.film_recipes
        set preset = ''
        where preset = new.preset
          and id <> new.id;
    end if;
    return new;
end;
$$;

drop trigger if exists film_recipes_unique_preset_slot on public.film_recipes;
create trigger film_recipes_unique_preset_slot
before insert or update of preset on public.film_recipes
for each row
execute function public.clear_duplicate_preset_slot();

alter table public.film_recipes enable row level security;

drop policy if exists "film_recipes_public_select" on public.film_recipes;
drop policy if exists "film_recipes_public_insert" on public.film_recipes;
drop policy if exists "film_recipes_public_update" on public.film_recipes;
drop policy if exists "film_recipes_public_delete" on public.film_recipes;

create policy "film_recipes_public_select"
on public.film_recipes for select
to anon
using (true);

create policy "film_recipes_public_insert"
on public.film_recipes for insert
to anon
with check (true);

create policy "film_recipes_public_update"
on public.film_recipes for update
to anon
using (true)
with check (true);

create policy "film_recipes_public_delete"
on public.film_recipes for delete
to anon
using (true);

create table if not exists public.recipe_parameters (
    parameter_key text primary key,
    label text not null,
    description text,
    value_type text not null check (value_type in ('enum', 'integer_range', 'decimal_range')),
    min_value numeric,
    max_value numeric,
    step_value numeric,
    allow_custom_value boolean not null default false,
    custom_value_hint text,
    sort_order integer not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint recipe_parameters_range_check check (
        (value_type = 'enum' and min_value is null and max_value is null and step_value is null)
        or (value_type in ('integer_range', 'decimal_range') and min_value is not null and max_value is not null and step_value is not null)
    )
);

create table if not exists public.recipe_parameter_options (
    parameter_key text not null references public.recipe_parameters (parameter_key) on delete cascade,
    option_value text not null,
    option_label text not null,
    sort_order integer not null,
    primary key (parameter_key, option_value)
);

create index if not exists recipe_parameters_sort_idx on public.recipe_parameters (sort_order);
create index if not exists recipe_parameter_options_sort_idx on public.recipe_parameter_options (parameter_key, sort_order);

drop trigger if exists recipe_parameters_set_updated_at on public.recipe_parameters;
create trigger recipe_parameters_set_updated_at
before update on public.recipe_parameters
for each row
execute function public.set_updated_at();

alter table public.recipe_parameters enable row level security;
alter table public.recipe_parameter_options enable row level security;

drop policy if exists "recipe_parameters_public_select" on public.recipe_parameters;
drop policy if exists "recipe_parameter_options_public_select" on public.recipe_parameter_options;

create policy "recipe_parameters_public_select"
on public.recipe_parameters for select
to anon
using (true);

create policy "recipe_parameter_options_public_select"
on public.recipe_parameter_options for select
to anon
using (true);

insert into public.recipe_parameters (
    parameter_key, label, description, value_type, min_value, max_value, step_value,
    allow_custom_value, custom_value_hint, sort_order
) values
('simulation', 'Film Simulation', 'Simulation de film Fujifilm utilisee par la recette.', 'enum', null, null, null, false, null, 10),
('dynamic_range', 'Dynamic Range', 'Etend la plage dynamique pour proteger les hautes et basses lumieres.', 'enum', null, null, null, false, null, 20),
('d_range_priority', 'D-Range Priority', 'Optimisation automatique de la plage dynamique.', 'enum', null, null, null, false, null, 30),
('preset', 'Preset Slot', 'Slot de preset assigne sur le boitier.', 'enum', null, null, null, false, null, 35),
('white_balance', 'White Balance', 'Balance des blancs de base de la recette.', 'enum', null, null, null, true, 'Si Other... est selectionne, la valeur libre (Kelvin ou texte) reste valide.', 40),
('expo_compensation', 'Exposure Compensation', 'Compensation d exposition conseillee par la recette.', 'enum', null, null, null, false, null, 50),
('shift_blue', 'Shift Blue', 'Ajustement fin de la balance des blancs sur l axe bleu-ambre.', 'integer_range', -6, 6, 1, false, null, 60),
('shift_red', 'Shift Red', 'Ajustement fin de la balance des blancs sur l axe rouge-vert.', 'integer_range', -6, 6, 1, false, null, 70),
('highlights', 'Highlights', 'Ajuste la luminosite des zones claires.', 'decimal_range', -2, 4, 0.5, false, null, 80),
('shadows', 'Shadows', 'Ajuste la luminosite des zones sombres.', 'decimal_range', -2, 4, 0.5, false, null, 90),
('color', 'Color (Saturation)', 'Intensite globale des couleurs.', 'integer_range', -4, 4, 1, false, null, 100),
('sharpness', 'Sharpness', 'Accentuation des contours.', 'integer_range', -4, 4, 1, false, null, 110),
('high_iso_nr', 'High ISO NR', 'Reduction du bruit numerique en hauts ISO.', 'integer_range', -4, 4, 1, false, null, 120),
('clarity', 'Clarity', 'Micro-contraste des tons moyens.', 'integer_range', -5, 5, 1, false, null, 130),
('grain_effect', 'Grain Effect', 'Ajoute un grain artificiel type pellicule.', 'enum', null, null, null, false, null, 140),
('grain_size', 'Grain Size', 'Taille du grain lorsque Grain Effect est actif.', 'enum', null, null, null, false, null, 150),
('color_chrome_effect', 'Color Chrome Effect', 'Renforce la profondeur des couleurs saturees.', 'enum', null, null, null, false, null, 160),
('color_chrome_fx_blue', 'Color Chrome FX Blue', 'Renforce specifiquement les tons bleus.', 'enum', null, null, null, false, null, 170),
('smooth_skin_effect', 'Smooth Skin Effect', 'Lissage automatique des textures de peau.', 'enum', null, null, null, false, null, 180)
on conflict (parameter_key) do update set
    label = excluded.label,
    description = excluded.description,
    value_type = excluded.value_type,
    min_value = excluded.min_value,
    max_value = excluded.max_value,
    step_value = excluded.step_value,
    allow_custom_value = excluded.allow_custom_value,
    custom_value_hint = excluded.custom_value_hint,
    sort_order = excluded.sort_order;

insert into public.recipe_parameter_options (
    parameter_key, option_value, option_label, sort_order
) values
('simulation', 'Provia', 'Provia', 10),
('simulation', 'Velvia', 'Velvia', 20),
('simulation', 'Astia', 'Astia', 30),
('simulation', 'Classic Chrome', 'Classic Chrome', 40),
('simulation', 'Reala Ace', 'Reala Ace', 50),
('simulation', 'Pro Neg Hi', 'Pro Neg Hi', 60),
('simulation', 'Pro Neg Std', 'Pro Neg Std', 70),
('simulation', 'Classic Neg', 'Classic Neg', 80),
('simulation', 'Nostalgic Neg', 'Nostalgic Neg', 90),
('simulation', 'Eterna', 'Eterna', 100),
('simulation', 'Eterna Bleach Bypass', 'Eterna Bleach Bypass', 110),
('simulation', 'Acros', 'Acros', 120),
('simulation', 'Monochrome', 'Monochrome', 130),
('simulation', 'Sepia', 'Sepia', 140),
('preset', 'FS1', 'FS1', 10),
('preset', 'FS2', 'FS2', 20),
('preset', 'FS3', 'FS3', 30),
('expo_compensation', '-2 to -3', '-2 to -3', 10),
('expo_compensation', '-1 to -2', '-1 to -2', 20),
('expo_compensation', '-1/3 to -1', '-1/3 to -1', 30),
('expo_compensation', '0', '0', 40),
('expo_compensation', '1/3 to 1', '1/3 to 1', 50),
('expo_compensation', '1 to 2', '1 to 2', 60),
('expo_compensation', '2 to 3', '2 to 3', 70),
('dynamic_range', 'Auto', 'Auto', 10),
('dynamic_range', 'DR100', 'DR100', 20),
('dynamic_range', 'DR200', 'DR200', 30),
('dynamic_range', 'DR400', 'DR400', 40),
('d_range_priority', 'Off', 'Off', 10),
('d_range_priority', 'Weak', 'Weak', 20),
('d_range_priority', 'Strong', 'Strong', 30),
('d_range_priority', 'Auto', 'Auto', 40),
('white_balance', 'Auto', 'Auto', 10),
('white_balance', 'Auto ambiance prio', 'Auto ambiance prio', 20),
('white_balance', 'Auto white prio', 'Auto white prio', 30),
('white_balance', 'Daylight', 'Daylight', 40),
('white_balance', 'Shade', 'Shade', 50),
('white_balance', 'Other...', 'Other...', 60),
('grain_effect', 'Off', 'Off', 10),
('grain_effect', 'Weak', 'Weak', 20),
('grain_effect', 'Strong', 'Strong', 30),
('grain_size', 'Small', 'Small', 10),
('grain_size', 'Large', 'Large', 20),
('color_chrome_effect', 'Off', 'Off', 10),
('color_chrome_effect', 'Weak', 'Weak', 20),
('color_chrome_effect', 'Strong', 'Strong', 30),
('color_chrome_fx_blue', 'Off', 'Off', 10),
('color_chrome_fx_blue', 'Weak', 'Weak', 20),
('color_chrome_fx_blue', 'Strong', 'Strong', 30),
('smooth_skin_effect', 'Off', 'Off', 10),
('smooth_skin_effect', 'Weak', 'Weak', 20),
('smooth_skin_effect', 'Strong', 'Strong', 30)
on conflict (parameter_key, option_value) do update set
    option_label = excluded.option_label,
    sort_order = excluded.sort_order;

create or replace view public.recipe_parameter_catalog as
select
    p.parameter_key,
    p.label,
    p.description,
    p.value_type,
    p.min_value,
    p.max_value,
    p.step_value,
    p.allow_custom_value,
    p.custom_value_hint,
    p.sort_order,
    coalesce(
        jsonb_agg(
            jsonb_build_object(
                'value', o.option_value,
                'label', o.option_label,
                'sort_order', o.sort_order
            )
            order by o.sort_order
        ) filter (where o.option_value is not null),
        '[]'::jsonb
    ) as options
from public.recipe_parameters p
left join public.recipe_parameter_options o
    on o.parameter_key = p.parameter_key
group by
    p.parameter_key,
    p.label,
    p.description,
    p.value_type,
    p.min_value,
    p.max_value,
    p.step_value,
    p.allow_custom_value,
    p.custom_value_hint,
    p.sort_order;

insert into public.film_recipes (
    id, name, clarity, color, color_chrome_effect, color_chrome_fx_blue, comment,
    d_range_priority, dynamic_range, expo_compensation, simulation, grain_effect,
    grain_size, high_iso_nr, highlights, rating, image_urls, preset, shadows, sort_order,
    sharpness, shift_blue, shift_red, smooth_skin_effect, white_balance, favorite
) values
('notion-1', 'Classic Cuban Neg', '-4', '+4', 'Strong', 'Strong', 'Voyage, Jour clair, Sunset', 'Off', 'DR400', '', 'Classic Neg', 'Strong', 'Large', '-4', '-2', '', array[]::text[], '', '+1', 0, '-4', '-5', '+3', 'Weak', 'Auto', false),
('notion-2', 'Cinematic Gold', '0', '+3', 'Off', 'Off', 'Soleil, Ombres, Contraste, Villes', 'Off', 'DR400', '', 'Classic Neg', 'Weak', 'Small', '-4', '0', '****', array[]::text[], 'FS2', '0', 1, '-2', '-5', '+4', 'Off', 'Daylight', true),
('notion-3', 'Reggie''s Portra', '0', '+2', 'Strong', 'Weak', '', 'Off', 'DR400', '+1/3 to +1', 'Classic Chrome', 'Weak', 'Small', '-4', '-1', '', array[]::text[], '', '-1', 2, '-2', '-4', '+2', 'Off', 'Auto', false),
('notion-4', 'Pure Chrome', '+1', '+4', 'Strong', 'Weak', '', 'Off', 'DR400', '', 'Classic Chrome', 'Off', '', '0', '+1', '', array[]::text[], '', '+0.5', 3, '-2', '-4', '+2', 'Off', 'Daylight', false),
('notion-5', 'Candy Dream', '-3', '+4', 'Weak', 'Weak', 'Clair, Doux, Lumineux', 'Off', 'DR400', '', 'Nostalgic Neg', 'Weak', 'Large', '-4', '-2', '', array[]::text[], 'FS1', '-2', 4, '+3', '+2', '+1', 'Weak', 'Auto ambiance pro', false),
('notion-6', 'Calm Optimist', '0', '+4', 'Strong', 'Strong', '', 'Off', 'DR400', '', 'Classic Neg', 'Off', '', '-2', '-2', '**', array[]::text[], '', '+1', 5, '+2', '-5', '+2', 'Off', 'Auto', false),
('notion-7', 'Winter Sea Clarity', '0', '+4', 'Strong', 'Strong', '', 'Off', 'DR100', '', 'Classic Chrome', 'Off', '', '0', '-1', '', array[]::text[], '', '-2', 6, '+1', '+1', '-1', 'Off', '4700K', false),
('notion-8', 'Lenscape', '-3', '-2', 'Weak', 'Weak', '', 'Off', 'DR400', '', 'Classic Neg', 'Weak', 'Small', '-2', '-2', '', array[]::text[], '', '+1', 7, '-1', '-1', '+2', 'Off', 'Auto', false),
('notion-9', 'Scottish Winter', '0', '+2', 'Weak', 'Weak', 'Polyvalent, tres colore et contraste', 'Off', 'DR400', '-', 'Velvia', 'Off', '', '+2', '+1', '***', array[]::text[], '', '+1', 8, '-1', '-2', '+3', 'Weak', 'Auto', false),
('notion-10', 'A tester', '0', '0', 'Strong', 'Weak', 'Warm tones, Soft contrast, Clean highlights', 'Off', 'DR200', '-1/3 to -1', 'Classic Neg', 'Weak', 'Small', '0', '-1', '', array[]::text[], '', '+1', 9, '-1', '0', '0', 'Weak', 'Auto', false),
('notion-11', 'Lea''s Recipe', '0', '+3', 'Strong', 'Weak', 'Lea''s recipe from Insta/TokTok', 'Off', 'DR400', '+1/3 to +1', 'Classic Chrome', 'Weak', 'Large', '-4', '-2', '', array[]::text[], '', '-0.5', 10, '-2', '-3', '-1', 'Weak', '6600K', false)
on conflict (id) do update set
    name = excluded.name,
    sort_order = excluded.sort_order,
    clarity = excluded.clarity,
    color = excluded.color,
    color_chrome_effect = excluded.color_chrome_effect,
    color_chrome_fx_blue = excluded.color_chrome_fx_blue,
    comment = excluded.comment,
    d_range_priority = excluded.d_range_priority,
    dynamic_range = excluded.dynamic_range,
    expo_compensation = excluded.expo_compensation,
    simulation = excluded.simulation,
    grain_effect = excluded.grain_effect,
    grain_size = excluded.grain_size,
    high_iso_nr = excluded.high_iso_nr,
    highlights = excluded.highlights,
    image_urls = excluded.image_urls,
    rating = excluded.rating,
    preset = excluded.preset,
    shadows = excluded.shadows,
    sharpness = excluded.sharpness,
    shift_blue = excluded.shift_blue,
    shift_red = excluded.shift_red,
    smooth_skin_effect = excluded.smooth_skin_effect,
    white_balance = excluded.white_balance,
    favorite = excluded.favorite;

insert into storage.buckets (id, name, public)
values ('recipe-images', 'recipe-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "recipe_images_public_select" on storage.objects;
drop policy if exists "recipe_images_public_insert" on storage.objects;
drop policy if exists "recipe_images_public_update" on storage.objects;
drop policy if exists "recipe_images_public_delete" on storage.objects;

create policy "recipe_images_public_select"
on storage.objects for select
to anon
using (bucket_id = 'recipe-images');

create policy "recipe_images_public_insert"
on storage.objects for insert
to anon
with check (bucket_id = 'recipe-images');

create policy "recipe_images_public_update"
on storage.objects for update
to anon
using (bucket_id = 'recipe-images')
with check (bucket_id = 'recipe-images');

create policy "recipe_images_public_delete"
on storage.objects for delete
to anon
using (bucket_id = 'recipe-images');