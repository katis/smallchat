import React from 'react';

type ButtonProps = {
  label: string;
  onClick: (event: React.MouseEvent<HTMLButtonElement>) => void;
};

export function Button<T extends string>({ label, onClick }: ButtonProps): JSX.Element {
  return (
    <button type="button" className="btn" onClick={onClick}>
      {label}
    </button>
  );
}
