-- M54: mobile completion reconciliation preserves the earliest completed-at
-- timestamp across local MMKV and user_actions.created_at. Keep the write
-- narrow: clients may only update created_at on their own action rows.

drop policy if exists "contributors update own action timestamps" on public.user_actions;
create policy "contributors update own action timestamps"
on public.user_actions for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

grant update (created_at) on public.user_actions to authenticated;
