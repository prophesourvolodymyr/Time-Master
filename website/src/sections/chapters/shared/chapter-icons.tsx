import { BarbellIcon, MapTrifoldIcon, RobotIcon, UsersThreeIcon, type Icon } from "@phosphor-icons/react";
import type { ChapterId } from "@/lib/site";

export const chapterIcons: Record<ChapterId, Icon> = {
  ai: RobotIcon,
  social: UsersThreeIcon,
  builder: BarbellIcon,
  map: MapTrifoldIcon,
};
