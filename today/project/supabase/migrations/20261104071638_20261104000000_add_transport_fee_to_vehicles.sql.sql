/*
# Add transport_fee column to vehicles table

1. Changes
- Adds `transport_fee` numeric column to `vehicles` table, defaulting to 0.
- Updates the `vehicle_save` RPC function to accept a `p_transport_fee` parameter
  and persist it on both insert and update paths.
2. Security
- No new tables. Existing RLS policies on `vehicles` are unchanged.
- The `vehicle_save` SECURITY DEFINER function gains one parameter; EXECUTE grants
  are already scoped to `anon, authenticated` and are re-granted to stay consistent.
3. Notes
- The column is nullable-safe with a DEFAULT of 0 so existing rows and old callers
  that omit the parameter continue to work without error.
*/

ALTER TABLE vehicles
  ADD COLUMN IF NOT EXISTS transport_fee numeric NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- Replace vehicle_save with a version that accepts transport_fee
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS vehicle_save(uuid, uuid, text, text, text, text);

CREATE OR REPLACE FUNCTION vehicle_save(
  p_staff_id uuid,
  p_id uuid,
  p_plate text,
  p_driver text,
  p_phone text,
  p_model text,
  p_transport_fee numeric DEFAULT 0
) RETURNS vehicles
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v vehicles; plate text := upper(trim(coalesce(p_plate, '')));
BEGIN
  IF NOT is_admin_user(p_staff_id) THEN RAISE EXCEPTION 'Admin access required.'; END IF;
  IF plate = '' THEN RAISE EXCEPTION 'Plate number is required.'; END IF;
  IF trim(coalesce(p_driver, '')) = '' THEN RAISE EXCEPTION 'Driver name is required.'; END IF;
  IF trim(coalesce(p_phone, '')) = '' THEN RAISE EXCEPTION 'Driver phone is required.'; END IF;

  IF p_id IS NULL THEN
    INSERT INTO vehicles (plate_number, driver_name, driver_phone, vehicle_model, transport_fee, status)
    VALUES (plate, trim(p_driver), trim(p_phone), trim(coalesce(p_model, '')), coalesce(p_transport_fee, 0), 'available')
    RETURNING * INTO v;
  ELSE
    UPDATE vehicles
    SET plate_number = plate, driver_name = trim(p_driver),
        driver_phone = trim(p_phone), vehicle_model = trim(coalesce(p_model, '')),
        transport_fee = coalesce(p_transport_fee, 0)
    WHERE id = p_id
    RETURNING * INTO v;
    IF NOT FOUND THEN RAISE EXCEPTION 'Truck not found.'; END IF;
  END IF;
  RETURN v;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'A truck with plate % is already registered.', plate;
END;
$$;

-- Re-grant EXECUTE on the new function signature (old signature is dropped).
GRANT EXECUTE ON FUNCTION vehicle_save(uuid, uuid, text, text, text, text, numeric) TO anon, authenticated;
