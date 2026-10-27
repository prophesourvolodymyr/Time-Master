import type { ComponentPropsWithRef, CSSProperties, ReactNode } from "react";
import clsx from "clsx";
import styles from "./action-button.module.css";

const controlCornerRadius = 18;

type ActionStyle = {
  prominent?: boolean;
  size?: number;
  expansion?: number;
  fillsWidth?: boolean;
  paddingX?: number;
  tint?: string;
  tone?: "default" | "destructive";
  font?: "wide" | "text" | "inherit";
  icon?: ReactNode;
  iconPosition?: "leading" | "trailing";
  disabled?: boolean;
  children?: ReactNode;
  className?: string;
  style?: CSSProperties;
};

type ButtonVariant = ActionStyle & Omit<ComponentPropsWithRef<"button">, keyof ActionStyle> & { href?: undefined };
type AnchorVariant = ActionStyle & Omit<ComponentPropsWithRef<"a">, keyof ActionStyle> & { href: string };

export type ActionButtonProps = ButtonVariant | AnchorVariant;

export type IconButtonProps = Omit<ActionButtonProps, "icon" | "iconPosition" | "children" | "fillsWidth" | "expansion" | "paddingX"> & {
  label: string;
  icon: ReactNode;
};

function actionCornerRadius(size: number, expansion: number, circular: boolean) {
  if (circular) return size / 2;
  return size / 2 + (controlCornerRadius - size / 2) * expansion;
}

function renderAction(props: ActionButtonProps, circular: boolean) {
  const {
    prominent = false,
    size = 44,
    expansion = 1,
    fillsWidth = false,
    paddingX = 14,
    tint,
    tone = "default",
    font = "wide",
    icon,
    iconPosition = "leading",
    disabled = false,
    children,
    className,
    style,
    ...native
  } = props;
  const clamped = Math.min(1, Math.max(0, expansion));
  const surfaceStyle = {
    ...style,
    "--size": `${size}px`,
    "--pad": `${circular ? 0 : paddingX * clamped}px`,
    "--radius": `${actionCornerRadius(size, clamped, circular)}px`,
    ...(tint ? { "--tint": tint } : null),
  } as CSSProperties;
  const classes = clsx(
    styles.button,
    prominent && styles.prominent,
    tone === "destructive" && styles.destructive,
    font !== "inherit" && styles[font],
    fillsWidth && !circular && styles.fill,
    circular && styles.circle,
    className,
  );
  const leading = icon && iconPosition === "leading" ? <span className={styles.icon} aria-hidden="true">{icon}</span> : null;
  const trailing = icon && iconPosition === "trailing" ? <span className={styles.icon} aria-hidden="true">{icon}</span> : null;

  if (native.href !== undefined) {
    const { href, ...anchor } = native;
    return (
      <a
        {...anchor}
        href={disabled ? undefined : href}
        role={disabled ? "link" : anchor.role}
        aria-disabled={disabled || undefined}
        className={classes}
        style={surfaceStyle}
      >
        {leading}
        {children}
        {trailing}
      </a>
    );
  }

  const { type = "button", ...button } = native;
  return (
    <button {...button} type={type} disabled={disabled} className={classes} style={surfaceStyle}>
      {leading}
      {children}
      {trailing}
    </button>
  );
}

export function ActionButton(props: ActionButtonProps) {
  return renderAction(props, false);
}

export function IconButton({ label, icon, ...props }: IconButtonProps) {
  return renderAction({ ...props, "aria-label": label, children: icon } as ActionButtonProps, true);
}
