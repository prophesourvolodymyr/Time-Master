import SwiftUI


extension ProfileView {
    private var chromeEntranceOpacity: Double {
        isChromeVisible || reduceMotion || rasterizedContent || isProfileRoot ? 1 : 0
    }

    private func chromeEntranceOffset(_ distance: CGFloat) -> CGFloat {
        isChromeVisible || reduceMotion || rasterizedContent || isProfileRoot ? 0 : -distance
    }

    private var chromeEntranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.36)
    }


    private func profileHeader(width: CGFloat, coverHeight: CGFloat, progress: CGFloat) -> some View {
        let control = EverLayout.minimumTouchTarget
        let topControl = EverLayout.minimumTouchTarget + EverSpacing.x1
        let inset = EverSpacing.x2
        let expandedCenter = coverHeight
        let expandedIdentityY = expandedCenter + expandedAvatarSize * 0.86 - EverSpacing.x3
        let addHeight = EverProfileGeometry.addButtonHeight
        let expandedAddY = expandedIdentityY + EverSpacing.x7 + addHeight / 2
        let stats = selectedStats
        let collapsingStat = stats.first
        let showsRankedIndicator = !asVisitor && onOpenRanked != nil
        let shieldWidth = min(
            EverLayout.minimumTouchTarget * 3 + EverSpacing.x4,
            max(0, (width - EverLayout.phoneInset * 2 - expandedAvatarSize - EverSpacing.x3 * 2) / 2)
        )
        let expandedStatY = expandedCenter + expandedAvatarSize * 0.55
        let compactAvatar = min(compactAvatarSize, EverLayout.standardRowMinimum)
        let addWidth = EverProfileGeometry.addButtonWidth
        let activeProfile = !asVisitor && !previewOnly
        let accessoryCount = 0
        let compactStatWidth = collapsingStat == nil
            ? 0
            : min(EverLayout.minimumTouchTarget + EverSpacing.x3, shieldWidth * 0.48)
        let compactPreEditWidth = compactStatWidth
            + (activeProfile ? control + (compactStatWidth > 0 ? EverSpacing.x1 : 0) : 0)
        let compact = EverProfileGeometry.compactHeader(
            width: width,
            avatarSize: compactAvatar,
            statWidth: compactPreEditWidth,
            addWidth: addWidth,
            accessoryCount: accessoryCount
        )
        let unusedBackSpace = isProfileRoot ? control + EverSpacing.x1 : 0
        let compactAvatarX = compact.avatarX - unusedBackSpace
        let compactNameLeading = compactAvatarX + compactAvatar / 2 + EverSpacing.x1
        let compactNameX = compactNameLeading + compact.titleWidth / 2
        let compactSettingsX = compact.addX - addWidth / 2 - EverSpacing.x1 - control / 2
        let compactShieldX = compact.addX - addWidth / 2 - EverSpacing.x1
            - (activeProfile ? control + EverSpacing.x1 : 0) - compactStatWidth / 2
        let compactBackX = inset + control / 2
        let layoutProgress = reduceMotion ? (progress >= 0.5 ? 1 : 0) : progress
        let topControlSize = interpolate(topControl, control, layoutProgress)
        let expandedTopControlY = topControl / 2
        let expandedBackX = inset + topControl / 2
        let expandedMoreX = width - inset - topControl / 2
        let avatarProgress = layoutProgress
        let nameProgress = layoutProgress
        let actionProgress = layoutProgress
        let shieldDock = layoutProgress
        let secondaryShieldExit = min(1, layoutProgress * 1.5)
        let shieldParallaxY = reduceMotion ? 0 : -coverHeight * layoutProgress * (1 - shieldDock) * 0.25
        let avatarSize = interpolate(expandedAvatarSize, compactAvatar, avatarProgress)
        let expandedNameWidth = stats.isEmpty
            ? max(1, width - EverLayout.phoneInset * 2)
            : max(1, width - (shieldWidth + EverLayout.phoneInset + EverSpacing.x3) * 2)
        let nameWidth = interpolate(expandedNameWidth, compact.titleWidth + unusedBackSpace, avatarProgress)
        let nameX = interpolate(width / 2, compact.titleX - unusedBackSpace / 2, nameProgress)
        let nameY = interpolate(expandedIdentityY, compactHeight / 2, nameProgress)
        let actionY = interpolate(expandedAddY, compactHeight / 2, actionProgress)
        let controlY = interpolate(expandedTopControlY, compactHeight / 2, layoutProgress)

        return ZStack(alignment: .topLeading) {
            profileBanner(width: width, coverHeight: coverHeight, progress: layoutProgress)

            if !previewOnly && !asVisitor {
                HStack(spacing: EverSpacing.x1) {
                    membershipButton
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, EverLayout.phoneInset)
                .frame(minHeight: topControl, alignment: .center)
                .opacity(chromeEntranceOpacity * (1 - layoutProgress))
                .offset(y: chromeEntranceOffset(8))
                .animation(chromeEntranceAnimation.delay(0.06), value: isChromeVisible)
                .allowsHitTesting(layoutProgress < 0.5)
                .accessibilityHidden(layoutProgress >= 0.5)
                marketplaceButton
                    .position(
                        x: EverLayout.phoneInset + control / 2,
                        y: topControl + EverSpacing.x2 + control / 2
                    )
                    .opacity(chromeEntranceOpacity * (1 - layoutProgress))
                    .allowsHitTesting(layoutProgress < 0.5)
                    .accessibilityHidden(layoutProgress >= 0.5)
            }

            profileAvatar(size: avatarSize)
                .position(
                    x: interpolate(width / 2, compactAvatarX, avatarProgress),
                    y: interpolate(expandedCenter, compactHeight / 2, avatarProgress)
                )
                .offset(y: chromeEntranceOffset(18))
                .opacity(chromeEntranceOpacity)
                .animation(chromeEntranceAnimation.delay(0.04), value: isChromeVisible)
                .allowsHitTesting(!previewOnly)
                .accessibilityIdentifier("profile-morph-avatar")

            VStack(spacing: interpolate(EverSpacing.x1, 0, layoutProgress)) {
                ProfileStyledName(text: profile.displayName)
                    .font(TimeMasterFont.title())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(reduceMotion ? 1 : interpolate(1, 0.8, layoutProgress))
                Text("@\(profile.handle)")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                    .opacity(1 - progress)
                    .frame(height: interpolate(EverSpacing.x5, 0, layoutProgress))
                    .clipped()
                    .accessibilityHidden(progress > 0.5)
            }
            .foregroundStyle(palette.foreground)
            .frame(width: nameWidth)
            .clipped()
            .contextMenu {
                if !previewOnly { profileActionItems }
            }
            .position(x: nameX, y: nameY)
            .offset(y: chromeEntranceOffset(12))
            .opacity(chromeEntranceOpacity * (1 - nameProgress))
            .animation(chromeEntranceAnimation.delay(0.08), value: isChromeVisible)

            ProfileStyledName(text: profile.displayName)
                .font(TimeMasterFont.rowTitle())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: compact.titleWidth, alignment: .leading)
                .position(x: compactNameX, y: controlY)
                .opacity(chromeEntranceOpacity * nameProgress)
                .accessibilityHidden(nameProgress < 0.5)

            if !stats.isEmpty {
                ForEach(stats) { stat in
                    let isCollapsingStat = stat.id == collapsingStat?.id
                    Group {
                        if stat == .trailing && showsRankedIndicator {
                            RankedProfileSummary { selectedTab = .ranked }
                        } else {
                            ProfileAchievementIndicator(
                                isLeading: stat == .leading,
                                showAll: showsRankedIndicator,
                                palette: palette.forSurface,
                                compactProgress: isCollapsingStat ? shieldDock : 0,
                                collectible: collectible(.badge),
                                artworkActive: collectibleArtworkActive
                            )
                        }
                    }
                    .frame(
                        width: interpolate(shieldWidth, compactStatWidth, isCollapsingStat ? shieldDock : 0),
                        height: interpolate(EverLayout.minimumTouchTarget * 2, EverLayout.minimumTouchTarget, isCollapsingStat ? shieldDock : 0)
                    )
                    .position(
                        x: interpolate(
                            stat.id == stats.first?.id
                                ? EverLayout.phoneInset + shieldWidth / 2
                                : width - EverLayout.phoneInset - shieldWidth / 2,
                            compactShieldX,
                            isCollapsingStat ? shieldDock : 0
                        ),
                        y: interpolate(expandedStatY, compactHeight / 2, isCollapsingStat ? shieldDock : 0) + (isCollapsingStat ? shieldParallaxY : 0)
                    )
                    .opacity(chromeEntranceOpacity * (isCollapsingStat ? 1 : 1 - secondaryShieldExit))
                    .offset(y: chromeEntranceOffset(10))
                    .animation(chromeEntranceAnimation.delay(0.1), value: isChromeVisible)
                    .allowsHitTesting(isCollapsingStat || secondaryShieldExit < 1)
                    .accessibilityHidden(!isCollapsingStat && secondaryShieldExit >= 1)
                    .accessibilityIdentifier(stat == .trailing && showsRankedIndicator ? "profile-ranked-summary" : "profile-stat-\(stat.rawValue)")
                }
            }

            Button {
                sheet = asVisitor ? .report : .edit
            } label: {
                Text(asVisitor ? "Report" : "Edit")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StoreCompactButtonStyle(
                isPrimary: false,
                minimumHeight: addHeight
            ))
            .frame(width: addWidth, height: addHeight)
            .disabled(previewOnly || (!asVisitor && profileStore.isReadOnly))
            .position(
                x: interpolate(width / 2, compact.addX, actionProgress),
                y: actionY
            )
            .offset(y: chromeEntranceOffset(8))
            .opacity(chromeEntranceOpacity)
            .animation(chromeEntranceAnimation.delay(0.12), value: isChromeVisible)
            .accessibilityLabel(asVisitor ? "Report profile" : "Edit profile")
            .accessibilityIdentifier(asVisitor ? "profile-report" : "profile-edit")

            if !isProfileRoot {
                backButton(size: topControlSize)
                    .position(x: interpolate(expandedBackX, compactBackX, layoutProgress), y: controlY)
                    .offset(y: chromeEntranceOffset(8))
                    .opacity(chromeEntranceOpacity)
                    .animation(chromeEntranceAnimation.delay(0.04), value: isChromeVisible)
            }
            if activeProfile {
                Button {
                    sheet = .compose
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: topControlSize, height: topControlSize)
                        .contentShape(Circle())
                }
                .buttonStyle(EverSpecularButtonStyle(radius: topControlSize / 2, horizontalPadding: 0))
                .disabled(profileStore.isReadOnly)
                .accessibilityLabel("Create post")
                .accessibilityIdentifier("profile-create-post")
                .position(
                    x: interpolate(width - inset - topControl * 2.5, compact.accessoryX(0), layoutProgress),
                    y: controlY
                )
                .opacity(compact.accessoryCount > 2 ? 1 : max(0, 1 - progress * 3))
                .opacity(chromeEntranceOpacity)
                .offset(y: chromeEntranceOffset(8))
                .animation(chromeEntranceAnimation.delay(0.04), value: isChromeVisible)
                .allowsHitTesting(compact.accessoryCount > 2 || progress < 0.2)
                .accessibilityHidden(compact.accessoryCount < 3 && progress >= 0.2)

                Button {
                    sheet = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.semibold))
                        .frame(width: topControlSize, height: topControlSize)
                        .contentShape(Circle())
                }
                .buttonStyle(EverSpecularButtonStyle(radius: topControlSize / 2, horizontalPadding: 0))
                .accessibilityLabel("Profile settings")
                .accessibilityIdentifier("profile-settings")
                .position(
                    x: interpolate(width - inset - topControl * 1.5, compactSettingsX, actionProgress),
                    y: controlY
                )
                .opacity(chromeEntranceOpacity)
                .offset(y: chromeEntranceOffset(8))
                .animation(chromeEntranceAnimation.delay(0.06), value: isChromeVisible)
            }
            if !previewOnly {
                profileActions(size: topControlSize)
                    .position(x: interpolate(expandedMoreX, compact.accessoryX(max(0, compact.accessoryCount - 1)), layoutProgress), y: controlY)
                    .opacity(compact.accessoryCount > 0 ? 1 : max(0, 1 - progress * 3))
                    .opacity(chromeEntranceOpacity)
                    .offset(y: chromeEntranceOffset(8))
                    .animation(chromeEntranceAnimation.delay(0.08), value: isChromeVisible)
                    .allowsHitTesting(compact.accessoryCount > 0 || progress < 0.2)
                    .accessibilityHidden(compact.accessoryCount == 0 && progress >= 0.2)
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-collapsing-header")
    }

    private func profileAvatar(size: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ProfileAvatar(profile: profile, size: size)
                .overlay(Circle().stroke(palette.background, lineWidth: size / 20))
            if let item = collectible(.avatar) {
                CollectibleAvatarRing(item: item, active: collectibleArtworkActive)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            profileAvatarVerificationMark(size: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func profileAvatarVerificationMark(size: CGFloat) -> some View {
        let markSize = max(EverSpacing.x6, min(34, size * 0.34))
        if let tier = verificationPreviewTier ?? profileStore.snapshot.badgePreview {
            Button { sheet = .verification } label: {
                ProfileVerificationBadge(tier: tier, size: markSize)
                    .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(EverPressButtonStyle())
            .disabled(previewOnly || asVisitor)
            .accessibilityLabel("\(profile.displayName)'s \(tier.title) checkmark Preview, not verified status")
            .accessibilityIdentifier("profile-badge-info")
        }
    }
    private func interpolate(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }


    private func profileBanner(width: CGFloat, coverHeight: CGFloat, progress: CGFloat) -> some View {
        CollectibleProfileCover(profile: profile)
            .overlay { ProfileBannerDecoration() }
            .modifier(EverProfileCoverMotion(width: width, coverHeight: coverHeight, compactHeight: compactHeight, progress: progress, background: palette.background))
            .overlay {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [palette.background.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: EverSpacing.x3)
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [.clear, palette.background.opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: EverSpacing.x3)
                }
                .allowsHitTesting(false)
            }
            .clipped()
            .opacity(chromeEntranceOpacity)
            .animation(chromeEntranceAnimation, value: isChromeVisible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    func collapsingChrome(width: CGFloat, coverHeight: CGFloat, expandedCore: CGFloat, expandedHeight: CGFloat, progress: CGFloat) -> some View {
        VStack(spacing: 0) {
            profileHeader(width: width, coverHeight: coverHeight, progress: progress)
                .frame(height: interpolate(expandedCore, compactHeight, progress), alignment: .top)
                .clipped()
            VStack(spacing: EverSpacing.x2) {
                expandedHeaderDetails
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, EverLayout.phoneInset)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { details in
                details.size.height
            } action: { height in
                detailsHeight = height
            }
            .opacity(Double(1 - progress) * chromeEntranceOpacity)
            .offset(y: chromeEntranceOffset(10))
            .animation(chromeEntranceAnimation.delay(0.16), value: isChromeVisible)
            .frame(height: progress == 0 ? nil : detailsHeight * (1 - progress), alignment: .top)
            .clipped()
            .allowsHitTesting(progress < 0.1)
            .accessibilityHidden(progress > 0.5)
            profileTabHeader
                .frame(height: tabHeight)
                .zIndex(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: interpolate(expandedHeight + tabHeight, compactHeight + tabHeight, progress), alignment: .top)
        .background(palette.background)
        .clipped()
    }
    private var profileTabHeader: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EverSpacing.x1) {
                        ForEach(tabs) { tab in
                            Button {
                                selectedTab = tab
                                withAnimation(reduceMotion ? nil : EverMotion.state) {
                                    proxy.scrollTo(tab.id, anchor: .center)
                                }
                            } label: {
                                EverPillTabLabel(
                                    title: tab.title,
                                    symbol: tab.symbol,
                                    isSelected: activeTab == tab
                                )
                            }
                            .buttonStyle(EverPillTabButtonStyle(isSelected: activeTab == tab))
                            .frame(minHeight: EverLayout.minimumTouchTarget)
                            .id(tab.id)
                            .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
                            .accessibilityIdentifier("profile-tab-\(tab.rawValue)")
                        }
                    }
                    .padding(.horizontal, EverLayout.phoneInset)
                }
                .padding(.top, EverSpacing.x1)
                .onAppear {
                    if let activeTab {
                        proxy.scrollTo(activeTab.id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            ProfileTabsSurface()
                .fill(palette.surface)
                .shadow(color: .black.opacity(0.28), radius: EverSpacing.x2, y: -EverSpacing.x1)
        }
        .opacity(chromeEntranceOpacity)
        .offset(y: chromeEntranceOffset(6))
        .animation(chromeEntranceAnimation.delay(0.2), value: isChromeVisible)
    }
}
