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
        let expandedAvatar = expandedProfileAvatar(width: width)
        let expandedIdentityY = profileIdentityTop(width: width) + identityHeight / 2
        let addHeight = control
        let expandedAddY = profileIdentityTop(width: width) + identityHeight + EverSpacing.x2 + addHeight / 2
        let stats = selectedStats
        let showsRankedIndicator = showsEarnedElo
        let collapsingStat = showsRankedIndicator ? stats.last : stats.first
        let shieldWidth = min(
            EverLayout.minimumTouchTarget * 3 + EverSpacing.x4,
            max(0, (width - EverLayout.phoneInset * 2 - expandedAvatar - EverSpacing.x3 * 2) / 2)
        )
        let expandedStatY = expandedCenter + expandedAvatar * 0.55
        let compactAvatar = min(compactAvatarSize, EverLayout.standardRowMinimum)
        let addWidth = control
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
        let avatarSize = interpolate(expandedAvatar, compactAvatar, avatarProgress)
        let compactIdentityY = showsRankedIndicator ? compactHeight / 2 + control / 2 + EverSpacing.x3 : compactHeight / 2
        let expandedNameOpacity = max(0, 1 - nameProgress * 2)
        let compactNameOpacity = max(0, (nameProgress - 0.55) / 0.45)
        let identityInk = LinearGradient(
            colors: [palette.foreground, palette.foreground.opacity(0.74)],
            startPoint: .top,
            endPoint: .bottom
        )
        let expandedNameWidth = max(1, width - EverLayout.phoneInset * 2)
        let nameWidth = interpolate(expandedNameWidth, compact.titleWidth + unusedBackSpace, avatarProgress)
        let nameX = interpolate(width / 2, compact.titleX - unusedBackSpace / 2, nameProgress)
        let nameY = interpolate(expandedIdentityY, showsRankedIndicator ? compactIdentityY + identityHeight / 2 : compactIdentityY, nameProgress)
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

            VStack(spacing: EverSpacing.x2) {
                ProfileStyledName(text: profile.displayName)
                    .font(TimeMasterFont.display())
                    .tracking(-0.5)
                    .foregroundStyle(identityInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(reduceMotion ? 1 : interpolate(1, 0.8, layoutProgress))
                    .accessibilityIdentifier("profile-user-name")
                Text("@\(profile.handle)")
                    .font(TimeMasterFont.caption())
                    .tracking(0.5)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                    .opacity(1 - progress)
                    .accessibilityHidden(progress > 0.5)
            }
            .foregroundStyle(palette.foreground)
            .frame(width: nameWidth)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                if layoutProgress == 0 { identityHeight = height }
            }
            .clipped()
            .onLongPressGesture {
                if !previewOnly { sheet = .actions }
            }
            .position(x: nameX, y: nameY)
            .offset(y: chromeEntranceOffset(12))
            .opacity(chromeEntranceOpacity * expandedNameOpacity)
            .animation(chromeEntranceAnimation.delay(0.08), value: isChromeVisible)
            .accessibilityHidden(nameProgress >= 0.5)

            ProfileStyledName(text: profile.displayName)
                .font(TimeMasterFont.rowTitle())
                .tracking(-0.2)
                .foregroundStyle(identityInk)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: compact.titleWidth)
                .position(
                    x: compactNameX,
                    y: compactIdentityY
                )
                .opacity(chromeEntranceOpacity * compactNameOpacity)
                .accessibilityHidden(nameProgress <= 0.55)
                .accessibilityIdentifier("profile-compact-user-name")

            if !stats.isEmpty {
                ForEach(stats) { stat in
                    let isCollapsingStat = stat.id == collapsingStat?.id
                    Group {
                        if stat == .trailing && showsRankedIndicator {
                            RankedProfileSummary(variation: rankedVariation, compact: shieldDock > 0.5, action: openRankedRating)
                                .disabled(previewOnly)
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
                        height: interpolate(stat == .trailing && showsRankedIndicator ? earnedEloBadgeHeight : control * 2, control, isCollapsingStat ? shieldDock : 0)
                    )
                    .position(
                        x: interpolate(
                            stat.id == stats.first?.id
                                ? EverLayout.phoneInset + shieldWidth / 2
                                : width - EverLayout.phoneInset - shieldWidth / 2,
                            showsRankedIndicator && stat == .trailing ? compactNameX : compactShieldX,
                            isCollapsingStat ? shieldDock : 0
                        ),
                        y: interpolate(expandedStatY, showsRankedIndicator ? compactHeight / 2 - EverSpacing.x2 : compactHeight / 2, isCollapsingStat ? shieldDock : 0) + (isCollapsingStat ? shieldParallaxY : 0)
                    )
                    .opacity(chromeEntranceOpacity * (isCollapsingStat ? 1 : 1 - secondaryShieldExit))
                    .offset(y: chromeEntranceOffset(10))
                    .animation(chromeEntranceAnimation.delay(0.1), value: isChromeVisible)
                    .allowsHitTesting(isCollapsingStat || secondaryShieldExit < 1)
                    .accessibilityHidden(!isCollapsingStat && secondaryShieldExit >= 1)
                    .accessibilityIdentifier(stat == .trailing && showsRankedIndicator ? "profile-earned-elo" : "profile-stat-\(stat.rawValue)")
                }
            }

            Button {
                sheet = asVisitor ? .report : .edit
            } label: {
                Image(systemName: asVisitor ? "flag" : "pencil")
                    .font(.body.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
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
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(width: topControlSize, height: topControlSize)
                        .contentShape(Circle())
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
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
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .contentShape(Circle())
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
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
            .overlay(palette.background.opacity(progress * 0.38))
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
