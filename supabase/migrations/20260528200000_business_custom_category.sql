alter table public.business_accounts
  add column if not exists custom_category text;

alter table public.business_accounts
  drop constraint if exists business_accounts_custom_category_length_check;

alter table public.business_accounts
  add constraint business_accounts_custom_category_length_check
  check (
    custom_category is null or
    length(trim(custom_category)) between 2 and 40
  ) not valid;

alter table public.business_accounts
  drop constraint if exists business_accounts_other_custom_category_check;

alter table public.business_accounts
  add constraint business_accounts_other_custom_category_check
  check (
    category <> 'Diğer' or
    (custom_category is not null and length(trim(custom_category)) > 0)
  ) not valid;
