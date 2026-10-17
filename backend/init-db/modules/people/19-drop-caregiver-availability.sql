-- Legacy cleanup: caregiver availability slots are no longer used.
DROP TABLE IF EXISTS people.caregiver_availability;
