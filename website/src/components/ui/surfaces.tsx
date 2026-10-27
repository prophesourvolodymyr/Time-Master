import type { ComponentPropsWithRef, CSSProperties, ElementType } from "react";
import clsx from "clsx";
import styles from "./surfaces.module.css";

type Polymorphic<T extends ElementType, Own> = Own & { as?: T } & Omit<ComponentPropsWithRef<T>, keyof Own | "as">;

export type CardSurfaceProps<T extends ElementType = "div"> = Polymorphic<
  T,
  { emphasized?: boolean; flat?: boolean; radius?: number; accent?: string; className?: string; style?: CSSProperties }
>;

export function CardSurface<T extends ElementType = "div">({
  as,
  emphasized = false,
  flat = false,
  radius,
  accent,
  className,
  style,
  ...rest
}: CardSurfaceProps<T>) {
  const Component: ElementType = as ?? "div";
  const surfaceStyle = {
    ...style,
    ...(radius === undefined ? null : { "--card-radius": `${radius}px` }),
    ...(accent ? { "--card-accent": accent } : null),
  } as CSSProperties;
  return (
    <Component
      {...rest}
      className={clsx(styles.card, flat && styles.flat, emphasized && styles.emphasized, className)}
      style={surfaceStyle}
    />
  );
}

export type GlassSurfaceProps<T extends ElementType = "div"> = Polymorphic<T, { tinted?: boolean; className?: string }>;

export function GlassSurface<T extends ElementType = "div">({ as, tinted = false, className, ...rest }: GlassSurfaceProps<T>) {
  const Component: ElementType = as ?? "div";
  return <Component {...rest} className={clsx(styles.glass, tinted && styles.glassTinted, className)} />;
}
