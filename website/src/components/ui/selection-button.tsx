import type { ComponentPropsWithRef } from "react";
import clsx from "clsx";
import styles from "./selection.module.css";

export type SelectionButtonProps = ComponentPropsWithRef<"button"> & {
  selected?: boolean;
};

export function SelectionButton({ selected = false, className, type = "button", role, ...props }: SelectionButtonProps) {
  return (
    <button
      {...props}
      type={type}
      role={role}
      aria-pressed={role ? undefined : selected}
      data-selected={selected || undefined}
      className={clsx(styles.selection, className)}
    />
  );
}
