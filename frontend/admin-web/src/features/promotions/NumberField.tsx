import { useId } from 'react';

export function NumberField({
  label,
  value,
  onChange,
  min = 0,
  max = Number.MAX_SAFE_INTEGER,
  disabled = false,
  optional = false,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  min?: number;
  max?: number;
  disabled?: boolean;
  optional?: boolean;
}) {
  const id = useId();
  return (
    <div className="promotion-number-field">
      <label htmlFor={id}>
        {label}
        <input
          id={id}
          type="number"
          step="1"
          min={min}
          max={max}
          required={!optional}
          aria-describedby={optional ? `${id}-help` : undefined}
          disabled={disabled}
          value={value}
          onChange={(e) => onChange(e.target.value)}
        />
      </label>
      {optional && <small id={`${id}-help`}>Để trống nếu không giới hạn.</small>}
    </div>
  );
}
