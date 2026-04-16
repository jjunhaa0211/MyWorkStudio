import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SettingsView {
    var templateTab: some View {
        let selectedKind = selectedTemplateKind
        let templateBinding = templateStore.binding(for: selectedKind)

        return VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.template.workflow", comment: ""), subtitle: selectedKind.displayName) {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(AutomationTemplateKind.allCases) { kind in
                            templateKindButton(kind)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: selectedKind.icon)
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.cyan)
                        Text(selectedKind.summary)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            settingsSection(title: NSLocalizedString("settings.template.editor", comment: ""), subtitle: NSLocalizedString("settings.template.autosave", comment: "")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        statusHint(
                            icon: templateStore.isCustomized(selectedKind) ? "slider.horizontal.3" : "checkmark.circle.fill",
                            text: templateStore.isCustomized(selectedKind) ? NSLocalizedString("settings.template.custom", comment: "") : NSLocalizedString("settings.template.default", comment: ""),
                            tint: templateStore.isCustomized(selectedKind) ? Theme.orange : Theme.green
                        )
                        Spacer()
                        Button(action: {
                            templateStore.reset(selectedKind)
                        }) {
                            Text(NSLocalizedString("settings.template.reset.current", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .orange, compact: true)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            showTemplateResetConfirm = true
                        }) {
                            Text(NSLocalizedString("settings.template.reset.all", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .red, compact: true)
                        }
                        .buttonStyle(.plain)
                    }

                    TextEditor(text: templateBinding)
                        .scrollContentBackground(.hidden)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minHeight: 260)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.bgSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.template.placeholders", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.textDim)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(selectedKind.placeholderTokens, id: \.self) { token in
                                templateTokenPill(token, tint: Theme.cyan)
                            }
                        }
                    }

                    if !selectedKind.pinnedLines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("settings.template.pinned", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                            Text(NSLocalizedString("settings.template.pinned.desc", comment: ""))
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                                ForEach(selectedKind.pinnedLines, id: \.self) { line in
                                    templateTokenPill(line, tint: Theme.purple)
                                }
                            }
                        }
                    }
                }
            }

            // ── 프롬프트 자동 주입 토글 ──
            settingsSection(title: NSLocalizedString("settings.template.prompt.toggle", comment: ""), subtitle: NSLocalizedString("settings.template.prompt.toggle.desc", comment: "")) {
                VStack(spacing: 8) {
                    // 마스터 토글: 모든 템플릿 일괄 비활성화
                    HStack(spacing: 8) {
                        Image(systemName: settings.allPromptsDisabled ? "slash.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: Theme.iconSize(12), weight: .bold))
                            .foregroundColor(settings.allPromptsDisabled ? Theme.red : Theme.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("settings.template.master.toggle", comment: ""))
                                .font(Theme.mono(10, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text(NSLocalizedString("settings.template.master.toggle.desc", comment: ""))
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.allPromptsDisabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(settings.allPromptsDisabled ? Theme.red.opacity(0.06) : Theme.green.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(settings.allPromptsDisabled ? Theme.red.opacity(0.2) : Theme.green.opacity(0.2), lineWidth: 1)
                    )

                    // 개별 역할 토글
                    VStack(spacing: 6) {
                        ForEach(AutomationTemplateKind.allCases) { kind in
                            HStack(spacing: 8) {
                                Image(systemName: kind.icon)
                                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                                    .foregroundColor(settings.isPromptEnabled(for: kind.rawValue) ? Theme.accent : Theme.textDim)
                                    .frame(width: 16)
                                Text(kind.displayName)
                                    .font(Theme.mono(10, weight: .medium))
                                    .foregroundColor(settings.isPromptEnabled(for: kind.rawValue) ? Theme.textPrimary : Theme.textDim)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { settings.isPromptEnabled(for: kind.rawValue) },
                                    set: { settings.setPromptEnabled($0, for: kind.rawValue) }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .disabled(settings.allPromptsDisabled)
                    .opacity(settings.allPromptsDisabled ? 0.4 : 1.0)
                }
            }

            // ── 파이프라인 순서 변경 ──
            settingsSection(title: NSLocalizedString("settings.template.pipeline", comment: ""), subtitle: NSLocalizedString("settings.template.pipeline.desc", comment: "")) {
                VStack(spacing: 8) {
                    ForEach(Array(settings.pipelineOrder.enumerated()), id: \.element) { index, roleKey in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                                .frame(width: 16)
                            if let kind = AutomationTemplateKind(rawValue: roleKey) {
                                Image(systemName: kind.icon)
                                    .font(.system(size: Theme.iconSize(10)))
                                    .foregroundColor(Theme.accent)
                                    .frame(width: 16)
                                Text(kind.displayName)
                                    .font(Theme.mono(10, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: Theme.iconSize(10)))
                                    .foregroundColor(Theme.purple)
                                    .frame(width: 16)
                                Text(roleKey)
                                    .font(Theme.mono(10, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Spacer()
                            if index > 0 {
                                Button(action: {
                                    var order = settings.pipelineOrder
                                    order.swapAt(index, index - 1)
                                    settings.pipelineOrder = order
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            if index < settings.pipelineOrder.count - 1 {
                                Button(action: {
                                    var order = settings.pipelineOrder
                                    order.swapAt(index, index + 1)
                                    settings.pipelineOrder = order
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Button(action: {
                                var order = settings.pipelineOrder
                                order.remove(at: index)
                                settings.pipelineOrder = order
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                    }

                    Button(action: { settings.resetPipelineOrder() }) {
                        Text(NSLocalizedString("settings.template.pipeline.reset", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .appButtonSurface(tone: .orange, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── 커스텀 직업 관리 ──
            settingsSection(title: NSLocalizedString("settings.template.custom.jobs", comment: ""), subtitle: NSLocalizedString("settings.template.custom.jobs.desc", comment: "")) {
                VStack(spacing: 8) {
                    ForEach(settings.customJobs) { job in
                        HStack(spacing: 8) {
                            Image(systemName: job.icon)
                                .font(.system(size: Theme.iconSize(10)))
                                .foregroundColor(Theme.purple)
                                .frame(width: 16)
                            Text(job.name)
                                .font(Theme.mono(10, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Button(action: {
                                settings.removeCustomJob(id: job.id)
                                var order = settings.pipelineOrder
                                order.removeAll { $0 == "custom_\(job.id)" }
                                settings.pipelineOrder = order
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                    }

                    if settings.customJobs.isEmpty {
                        Text(NSLocalizedString("settings.template.custom.jobs.empty", comment: ""))
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    HStack(spacing: 8) {
                        TextField(NSLocalizedString("settings.template.custom.jobs.name", comment: ""), text: $vm.newCustomJobName)
                            .textFieldStyle(.plain)
                            .font(Theme.mono(10))
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))

                        Button(action: {
                            let trimmed = newCustomJobName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            let job = CustomJob(name: trimmed)
                            settings.addCustomJob(job)
                            var order = settings.pipelineOrder
                            order.append("custom_\(job.id)")
                            settings.pipelineOrder = order
                            newCustomJobName = ""
                        }) {
                            Text(NSLocalizedString("settings.template.custom.jobs.add", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .accent, compact: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 플러그인 탭

    var pluginTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("plugin.section.add", comment: ""), subtitle: NSLocalizedString("plugin.section.add.subtitle", comment: "")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField(NSLocalizedString("plugin.input.placeholder", comment: ""), text: $vm.pluginSourceInput)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.5), lineWidth: 1))
                            .onSubmit { installPlugin() }

                        Button(action: { installPlugin() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                Text(NSLocalizedString("plugin.btn.install", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(pluginManager.isInstalling ? Theme.textDim : Theme.accent))
                        }
                        .buttonStyle(.plain)
                        .disabled(pluginManager.isInstalling || pluginSourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // 로컬 폴더 선택 + 새 플러그인 생성
                    HStack(spacing: 8) {
                        Button(action: { pickLocalPluginFolder() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                                Text(NSLocalizedString("plugin.btn.local", comment: ""))
                                    .font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cyan.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cyan.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Button(action: { showPluginScaffold = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                                Text(NSLocalizedString("plugin.btn.create", comment: ""))
                                    .font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.green)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Button(action: { showDebugConsole = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "ant.fill")
                                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                                Text(NSLocalizedString("plugin.btn.debug", comment: "Debug"))
                                    .font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.orange)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.orange.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.orange.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        pluginFormatHint(icon: "mug.fill", text: NSLocalizedString("plugin.format.brew", comment: ""), example: "formula-name")
                        pluginFormatHint(icon: "arrow.triangle.branch", text: NSLocalizedString("plugin.format.tap", comment: ""), example: "user/tap/formula")
                        pluginFormatHint(icon: "link", text: NSLocalizedString("plugin.format.url", comment: ""), example: "https://…/plugin.tar.gz")
                        pluginFormatHint(icon: "folder.fill", text: NSLocalizedString("plugin.format.local", comment: ""), example: "~/my-plugins/my-plugin")
                    }

                    if pluginManager.isInstalling {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(pluginManager.installProgress)
                                .font(Theme.mono(9))
                                .foregroundColor(Theme.cyan)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cyan.opacity(0.08)))
                    }

                    if let error = pluginManager.lastError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: Theme.iconSize(11), weight: .bold))
                                .foregroundColor(Theme.red)
                            Text(error)
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.red)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button(action: { pluginManager.lastError = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textDim)
                            }.buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.red.opacity(0.08)))
                    }
                }
            }

            settingsSection(
                title: NSLocalizedString("plugin.section.installed", comment: ""),
                subtitle: String(format: NSLocalizedString("plugin.section.installed.count", comment: ""),
                                 pluginManager.plugins.count,
                                 pluginManager.plugins.filter { $0.enabled }.count)
            ) {
                if pluginManager.plugins.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: Theme.iconSize(14), weight: .light))
                            .foregroundColor(Theme.textDim)
                        Text(NSLocalizedString("plugin.empty", comment: ""))
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(pluginManager.plugins) { plugin in
                            pluginRow(plugin)
                        }
                    }
                }
            }

            // 마켓플레이스
            settingsSection(
                title: NSLocalizedString("plugin.marketplace", comment: ""),
                subtitle: pluginManager.isLoadingRegistry
                    ? NSLocalizedString("plugin.marketplace.loading", comment: "")
                    : String(format: NSLocalizedString("plugin.marketplace.count", comment: ""), pluginManager.registryPlugins.count)
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Button(action: { pluginManager.fetchRegistry() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                                Text(NSLocalizedString("plugin.marketplace.refresh", comment: ""))
                                    .font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundStyle(Theme.accentBackground)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)
                        .disabled(pluginManager.isLoadingRegistry)

                        // 일괄 업데이트 버튼
                        if !pluginManager.updatablePlugins.isEmpty {
                            Button(action: { pluginManager.updateAllPlugins() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                                    Text(String(format: NSLocalizedString("plugin.update.count", comment: ""), pluginManager.updatablePlugins.count))
                                        .font(Theme.mono(9, weight: .medium))
                                }
                                .foregroundColor(Theme.green)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.2), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }

                        Spacer()

                        Text(NSLocalizedString("plugin.marketplace.hint", comment: ""))
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textDim)
                    }

                    // 검색바
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textDim)
                        TextField(NSLocalizedString("plugin.search.placeholder", comment: ""), text: $pluginManager.searchQuery)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.5), lineWidth: 1))

                    // 태그 필터
                    if !pluginManager.allRegistryTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(pluginManager.allRegistryTags.prefix(10), id: \.tag) { item in
                                    let isSelected = pluginManager.selectedTags.contains(item.tag)
                                    Button(action: {
                                        if isSelected { pluginManager.selectedTags.remove(item.tag) }
                                        else { pluginManager.selectedTags.insert(item.tag) }
                                    }) {
                                        HStack(spacing: 3) {
                                            Text("#\(item.tag)")
                                                .font(Theme.mono(8, weight: isSelected ? .bold : .regular))
                                            Text("\(item.count)")
                                                .font(Theme.mono(7))
                                                .foregroundColor(isSelected ? Theme.accent : Theme.textDim)
                                        }
                                        .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isSelected ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                    }.buttonStyle(.plain)
                                }

                                if !pluginManager.selectedTags.isEmpty {
                                    Button(action: { pluginManager.selectedTags.removeAll() }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.textDim)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if pluginManager.isLoadingRegistry {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(NSLocalizedString("plugin.marketplace.loading", comment: ""))
                                .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                        }
                    }

                    if let error = pluginManager.registryError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10)).foregroundColor(Theme.orange)
                            Text(error)
                                .font(Theme.mono(8)).foregroundColor(Theme.orange)
                                .lineLimit(2)
                        }
                    }

                    // 카테고리 탭
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(PluginCategory.allCases) { category in
                                let isActive = pluginManager.marketplaceCategory == category
                                Button(action: { pluginManager.marketplaceCategory = category }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 8, weight: .medium))
                                        Text(category.label)
                                            .font(Theme.mono(8, weight: isActive ? .bold : .regular))
                                    }
                                    .foregroundColor(isActive ? Theme.accent : Theme.textSecondary)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isActive ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isActive ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }.buttonStyle(.plain)
                            }

                            Spacer()

                            // 정렬 옵션
                            Menu {
                                ForEach(PluginSortOption.allCases) { option in
                                    Button(action: { pluginManager.marketplaceSortOption = option }) {
                                        HStack {
                                            Text(option.label)
                                            if pluginManager.marketplaceSortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 8, weight: .medium))
                                    Text(pluginManager.marketplaceSortOption.label)
                                        .font(Theme.mono(8))
                                }
                                .foregroundColor(Theme.textDim)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 100)
                        }
                    }

                    // Featured 섹션 (검색 없을 때만)
                    if pluginManager.searchQuery.isEmpty && pluginManager.selectedTags.isEmpty && pluginManager.marketplaceCategory == .all {
                        let featured = pluginManager.featuredPlugins
                        if !featured.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Theme.yellow)
                                    Text(NSLocalizedString("plugin.featured", comment: "Featured"))
                                        .font(Theme.mono(9, weight: .bold))
                                        .foregroundColor(Theme.yellow)
                                }
                                ForEach(featured) { item in
                                    marketplaceCard(item)
                                }
                            }

                            Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1)
                                .padding(.vertical, 4)
                        }
                    }

                    // 플러그인 목록
                    let filtered = pluginManager.filteredRegistryPlugins
                    if !filtered.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(filtered) { item in
                                marketplaceCard(item)
                            }
                        }
                    } else if !pluginManager.isLoadingRegistry && pluginManager.registryError == nil {
                        HStack(spacing: 8) {
                            Image(systemName: pluginManager.searchQuery.isEmpty && pluginManager.selectedTags.isEmpty ? "tray" : "magnifyingglass")
                                .font(.system(size: Theme.iconSize(12), weight: .light))
                                .foregroundColor(Theme.textDim)
                            Text(pluginManager.searchQuery.isEmpty && pluginManager.selectedTags.isEmpty
                                 ? NSLocalizedString("plugin.marketplace.empty", comment: "")
                                 : NSLocalizedString("plugin.search.empty", comment: ""))
                                .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
            }

            // 정보
            settingsSection(title: NSLocalizedString("plugin.section.info", comment: ""), subtitle: NSLocalizedString("plugin.section.info.subtitle", comment: "")) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: Theme.iconSize(11), weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                    Text(NSLocalizedString("plugin.info.desc", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            if pluginManager.registryPlugins.isEmpty && !pluginManager.isLoadingRegistry {
                pluginManager.fetchRegistry()
            }
            pluginManager.startWatchingLocalPlugins()
        }
        .onDisappear {
            pluginManager.stopWatchingAll()
        }
        .alert(NSLocalizedString("plugin.confirm.uninstall", comment: ""), isPresented: $vm.showPluginUninstallConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let plugin = pluginToUninstall {
                    pluginManager.uninstall(plugin)
                    pluginToUninstall = nil
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pluginToUninstall = nil }
        } message: {
            Text(String(format: NSLocalizedString("plugin.confirm.uninstall.msg", comment: ""), pluginToUninstall?.name ?? ""))
        }
        .alert(NSLocalizedString("plugin.permission.title", comment: ""),
               isPresented: Binding(
                   get: { pluginManager.pendingPermission != nil },
                   set: { if !$0 { pluginManager.denyPermission() } }
               )) {
            Button(NSLocalizedString("plugin.permission.allow", comment: "")) {
                pluginManager.approvePermission(alwaysTrust: false)
            }
            Button(NSLocalizedString("plugin.permission.always", comment: "")) {
                pluginManager.approvePermission(alwaysTrust: true)
            }
            Button(NSLocalizedString("plugin.permission.deny", comment: ""), role: .cancel) {
                pluginManager.denyPermission()
            }
        } message: {
            if let req = pluginManager.pendingPermission {
                Text(String(format: NSLocalizedString("plugin.permission.desc", comment: ""),
                            req.pluginName, URL(fileURLWithPath: req.scriptPath).lastPathComponent))
            }
        }
        .sheet(isPresented: $vm.showPluginScaffold) {
            PluginScaffoldSheet(onScaffold: { name, options in
                scaffoldNewPlugin(name: name, options: options)
            }, onDismiss: { showPluginScaffold = false })
            .dofficeSheetPresentation()
        }
        .sheet(isPresented: $vm.showDebugConsole) {
            PluginDebugView()
                .frame(minWidth: 560, minHeight: 400)
                .dofficeSheetPresentation()
        }
    }

    func installPlugin() {
        let source = pluginSourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        pluginManager.install(source: source)
        pluginSourceInput = ""
    }

    func pickLocalPluginFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = NSLocalizedString("plugin.picker.message", comment: "")
        panel.prompt = NSLocalizedString("plugin.picker.prompt", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            pluginManager.install(source: url.path)
        }
        #endif
    }

    func scaffoldNewPlugin(name: String? = nil, options: PluginManager.ScaffoldOptions? = nil) {
        let pluginName = (name ?? scaffoldName).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pluginName.isEmpty else { return }

        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = NSLocalizedString("plugin.scaffold.pick.dir", comment: "")
        panel.prompt = NSLocalizedString("plugin.scaffold.pick.prompt", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            if let pluginPath = pluginManager.scaffold(name: pluginName, at: url.path, options: options ?? PluginManager.ScaffoldOptions()) {
                pluginManager.install(source: pluginPath)
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: pluginPath)
            }
        }
        #endif
        scaffoldName = ""
        showPluginScaffold = false
    }

    func pluginTypeIcon(_ type: PluginEntry.SourceType) -> String {
        switch type {
        case .brewFormula, .brewTap: return "mug.fill"
        case .rawURL: return "link.circle.fill"
        case .local: return "folder.circle.fill"
        }
    }

    func pluginRow(_ plugin: PluginEntry) -> some View {
        let isExpanded = expandedPluginId == plugin.id
        let hasUpdate = pluginManager.hasUpdate(plugin)
        let badges = pluginManager.contributionSummary(for: plugin)
        let depIssues = pluginManager.validateDependencies(for: plugin.localPath)
        let pathMissing = plugin.enabled && pluginManager.resolvedPath(for: plugin) == nil

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 확장 토글
                Button(action: { withAnimation(.easeOut(duration: 0.2)) {
                    expandedPluginId = isExpanded ? nil : plugin.id
                }}) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 12)
                }.buttonStyle(.plain)

                Image(systemName: pathMissing ? "exclamationmark.triangle.fill" : pluginTypeIcon(plugin.sourceType))
                    .font(.system(size: Theme.iconSize(14), weight: .bold))
                    .foregroundColor(pathMissing ? Theme.orange : (plugin.enabled ? Theme.accent : Theme.textDim))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plugin.name)
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(plugin.enabled ? Theme.textPrimary : Theme.textDim)
                        // 업데이트 배지
                        if hasUpdate, let newVer = pluginManager.availableVersion(for: plugin) {
                            Text("v\(newVer)")
                                .font(Theme.mono(7, weight: .bold))
                                .foregroundColor(Theme.green)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.green.opacity(0.12)))
                        }
                        // 신뢰 상태
                        if pluginManager.isPluginTrusted(plugin.name) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.green.opacity(0.7))
                                .help(NSLocalizedString("plugin.permission.trusted", comment: ""))
                        }
                        // 의존성 경고
                        if !depIssues.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.orange)
                                .help(depIssues.map { $0.localizedMessage }.joined(separator: "\n"))
                        }
                    }
                    if pathMissing {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 9))
                            Text(NSLocalizedString("plugin.path.missing", comment: ""))
                                .font(Theme.mono(8, weight: .medium))
                        }
                        .foregroundColor(Theme.orange)
                    }
                    HStack(spacing: 6) {
                        Text("v\(plugin.version)")
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textDim)
                        Text("\u{00B7}").foregroundColor(Theme.textDim)
                        Text(plugin.source)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textDim)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { plugin.enabled },
                    set: { _ in pluginManager.toggleEnabled(plugin) }
                ))
                .toggleStyle(.switch).tint(Theme.green).labelsHidden().controlSize(.mini)

                // 업데이트 버튼
                if hasUpdate {
                    Button(action: { pluginManager.updatePlugin(plugin) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: Theme.iconSize(12), weight: .medium))
                            .foregroundColor(Theme.green)
                    }.buttonStyle(.plain)
                }

                #if os(macOS)
                // 내보내기
                Button(action: { pluginManager.exportPlugin(plugin) }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: Theme.iconSize(11), weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }.buttonStyle(.plain)
                .help(NSLocalizedString("plugin.export", comment: ""))

                // Finder에서 열기
                Button(action: { pluginManager.revealInFinder(plugin) }) {
                    Image(systemName: "folder")
                        .font(.system(size: Theme.iconSize(11), weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }.buttonStyle(.plain)

                // brew 업그레이드 (brew만)
                if plugin.sourceType == .brewFormula || plugin.sourceType == .brewTap {
                    Button(action: { pluginManager.upgrade(plugin) }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: Theme.iconSize(12), weight: .medium))
                            .foregroundColor(Theme.cyan)
                    }.buttonStyle(.plain)
                }
                #endif

                Button(action: {
                    pluginToUninstall = plugin
                    showPluginUninstallConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: Theme.iconSize(11), weight: .medium))
                        .foregroundColor(Theme.red.opacity(0.7))
                }.buttonStyle(.plain)
            }
            .padding(10)

            // 확장 상세 정보
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // 기여 배지
                    if !badges.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                                    HStack(spacing: 3) {
                                        Image(systemName: badge.icon)
                                            .font(.system(size: 9, weight: .medium))
                                        Text("\(badge.label) \(badge.count)")
                                            .font(Theme.mono(8, weight: .medium))
                                    }
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08)))
                                }
                            }
                        }
                    }

                    // 의존성 경고
                    if !depIssues.isEmpty {
                        ForEach(Array(depIssues.enumerated()), id: \.offset) { _, issue in
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9)).foregroundColor(Theme.orange)
                                Text(issue.localizedMessage)
                                    .font(Theme.mono(8)).foregroundColor(Theme.orange)
                            }
                        }
                    }

                    // 개별 확장 포인트 토글
                    extensionToggles(for: plugin)

                    // 충돌 경고
                    let conflicts = pluginManager.conflicts(for: plugin.name)
                    if !conflicts.isEmpty {
                        ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                                    .font(.system(size: 9)).foregroundColor(Theme.red)
                                Text(conflict.localizedMessage)
                                    .font(Theme.mono(7)).foregroundColor(Theme.red)
                            }
                        }
                    }

                    // 경로 누락 상세 + 재설치 안내
                    if pathMissing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: NSLocalizedString("plugin.path.missing.detail", comment: ""), plugin.localPath))
                                .font(Theme.mono(7))
                                .foregroundColor(Theme.orange)
                                .textSelection(.enabled)

                            HStack(spacing: 8) {
                                Button(action: {
                                    pluginManager.reinstallIfPossible(plugin)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(NSLocalizedString("plugin.reinstall", comment: ""))
                                            .font(Theme.mono(8, weight: .bold))
                                    }
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.1)))
                                }
                                .buttonStyle(.plain)

                                #if os(macOS)
                                Button(action: {
                                    let dir = PluginManager.defaultPluginBaseDir()
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(NSLocalizedString("plugin.open.folder", comment: ""))
                                            .font(Theme.mono(8, weight: .bold))
                                    }
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgCard))
                                }
                                .buttonStyle(.plain)
                                #endif
                            }
                        }
                    }

                    // 설치 정보
                    HStack(spacing: 10) {
                        Text(String(format: NSLocalizedString("plugin.detail.installed", comment: ""), plugin.installedAt.formatted(.dateTime.year().month().day())))
                            .font(Theme.mono(7)).foregroundColor(Theme.textDim)
                        Text(String(format: NSLocalizedString("plugin.detail.type", comment: ""), plugin.sourceType.rawValue))
                            .font(Theme.mono(7)).foregroundColor(Theme.textDim)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(plugin.enabled ? Theme.bgSurface : Theme.bgSurface.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
            pathMissing ? Theme.orange.opacity(0.5) : (hasUpdate ? Theme.green.opacity(0.4) : (plugin.enabled ? Theme.border.opacity(0.4) : Theme.border.opacity(0.2))),
            lineWidth: (pathMissing || hasUpdate) ? 1.5 : 1
        ))
    }

    @ViewBuilder
    func extensionToggles(for plugin: PluginEntry) -> some View {
        let baseURL = URL(fileURLWithPath: plugin.localPath)
        let manifestURL = baseURL.appendingPathComponent("plugin.json")

        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data),
           let c = manifest.contributes {
            let allExtensions = collectExtensionIds(pluginName: manifest.name, contributes: c)
            if !allExtensions.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(allExtensions, id: \.id) { ext in
                        HStack(spacing: 6) {
                            Image(systemName: ext.icon)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(pluginManager.isExtensionEnabled(ext.id) ? Theme.accent : Theme.textDim)
                                .frame(width: 12)
                            Text(ext.label)
                                .font(Theme.mono(8))
                                .foregroundColor(pluginManager.isExtensionEnabled(ext.id) ? Theme.textPrimary : Theme.textDim)
                            Spacer()
                            Button(action: { pluginManager.toggleExtension(ext.id) }) {
                                Text(pluginManager.isExtensionEnabled(ext.id)
                                     ? NSLocalizedString("plugin.extension.enable", comment: "")
                                     : NSLocalizedString("plugin.extension.disable", comment: ""))
                                    .font(Theme.mono(7, weight: .medium))
                                    .foregroundColor(pluginManager.isExtensionEnabled(ext.id) ? Theme.green : Theme.textDim)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(
                                        pluginManager.isExtensionEnabled(ext.id) ? Theme.green.opacity(0.08) : Theme.bgSurface
                                    ))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5)))
            }
        }
    }

    struct ExtensionInfo: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    func collectExtensionIds(pluginName: String, contributes c: PluginManifest.PluginContributions) -> [ExtensionInfo] {
        var items: [ExtensionInfo] = []
        if let themes = c.themes {
            for t in themes {
                items.append(ExtensionInfo(id: "\(pluginName)::\(t.id)", icon: "paintpalette.fill", label: t.name))
            }
        }
        if let effects = c.effects {
            for e in effects {
                items.append(ExtensionInfo(id: "\(pluginName)::\(e.id)", icon: "sparkles", label: "\(e.type) → \(e.trigger)"))
            }
        }
        if let panels = c.panels {
            for p in panels {
                items.append(ExtensionInfo(id: "\(pluginName)::\(p.id)", icon: "rectangle.on.rectangle", label: p.title))
            }
        }
        if let commands = c.commands {
            for cmd in commands {
                items.append(ExtensionInfo(id: "\(pluginName)::\(cmd.id)", icon: "terminal", label: cmd.title))
            }
        }
        if let achievements = c.achievements {
            for a in achievements {
                items.append(ExtensionInfo(id: "\(pluginName)::\(a.id)", icon: "trophy.fill", label: a.name))
            }
        }
        return items
    }

    func pluginFormatHint(icon: String, text: String, example: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(9), weight: .medium))
                .foregroundColor(Theme.textDim)
                .frame(width: 14)
            Text(text)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textDim)
            Text(example)
                .font(Theme.mono(8, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.bgSurface))
        }
    }

    func marketplaceRow(_ item: RegistryPlugin) -> some View {
        let installed = pluginManager.isInstalled(item)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("v\(item.version)")
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                    if item.characterCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 7))
                            Text("\(item.characterCount)")
                                .font(Theme.mono(7, weight: .medium))
                        }
                        .foregroundColor(Theme.purple)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Theme.purple.opacity(0.1)))
                    }
                }
                Text(item.description)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("by \(item.author)")
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                    if !item.tags.isEmpty {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(Theme.mono(6, weight: .medium))
                                .foregroundColor(Theme.cyan)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.cyan.opacity(0.08)))
                        }
                    }
                }
            }

            Spacer()

            if installed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(NSLocalizedString("plugin.marketplace.installed", comment: ""))
                        .font(Theme.mono(8, weight: .medium))
                }
                .foregroundColor(Theme.green)
            } else {
                Button(action: { pluginManager.installFromRegistry(item) }) {
                    Text(NSLocalizedString("plugin.btn.install", comment: ""))
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentBackground))
                }
                .buttonStyle(.plain)
                .disabled(pluginManager.isInstalling)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Marketplace Card (리디자인)

    func marketplaceCard(_ item: RegistryPlugin) -> some View {
        let installed = pluginManager.isInstalled(item)
        let hasStars = (item.stars ?? 0) > 0

        return VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(Theme.mono(11, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("v\(item.version)")
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textDim)
                    }
                    Text("by \(item.author)")
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }

                Spacer()

                if hasStars {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.yellow)
                        Text("\(item.stars ?? 0)")
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.yellow)
                    }
                }
            }

            // Description
            Text(item.description)
                .font(Theme.mono(9))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Badges & Tags
            HStack(spacing: 6) {
                if item.characterCount > 0 {
                    contributionPill(icon: "person.fill", text: "\(item.characterCount)", tint: Theme.purple)
                }
                ForEach(item.tags.prefix(4), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(Theme.mono(7, weight: .medium))
                        .foregroundColor(Theme.cyan)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Theme.cyan.opacity(0.06)))
                }
                Spacer()

                // Install button
                if installed {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                        Text(NSLocalizedString("plugin.marketplace.installed", comment: ""))
                            .font(Theme.mono(8, weight: .medium))
                    }
                    .foregroundColor(Theme.green)
                } else {
                    Button(action: { pluginManager.installFromRegistry(item) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: Theme.iconSize(10), weight: .bold))
                            Text(NSLocalizedString("plugin.btn.install", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentBackground))
                    }
                    .buttonStyle(.plain)
                    .disabled(pluginManager.isInstalling)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgSurface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            installed ? Theme.green.opacity(0.2) : Theme.border.opacity(0.3), lineWidth: 1
        ))
    }

    func contributionPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7))
            Text(text).font(Theme.mono(7, weight: .medium))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(tint.opacity(0.08)))
    }

    var supportTab: some View {
        VStack(spacing: 14) {
            CoffeeSupportPopoverView(embedded: true)
        }
    }

}

// MARK: - Plugin Scaffold Sheet (템플릿 선택기)

struct PluginScaffoldSheet: View {
    var onScaffold: (String, PluginManager.ScaffoldOptions) -> Void
    var onDismiss: () -> Void

    @State private var pluginName = ""
    @State private var pluginDescription = ""
    @State private var pluginAuthor = ""
    @State private var selectedTemplate: PluginTemplate = .fullPlugin

    // Feature toggles
    @State private var includeHooks = true
    @State private var includeSlashCommands = true
    @State private var includeCharacters = true
    @State private var includePanel = true
    @State private var includeThemes = false
    @State private var includeEffects = false
    @State private var includeFurniture = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.system(size: Theme.iconSize(14), weight: .bold))
                    .foregroundColor(Theme.green)
                Text(NSLocalizedString("plugin.scaffold.title", comment: ""))
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Template selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("plugin.scaffold.template", comment: "Template"))
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(PluginTemplate.allCases) { template in
                                templateCard(template)
                            }
                        }
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("plugin.scaffold.name.label", comment: ""))
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        TextField(NSLocalizedString("plugin.scaffold.name.placeholder", comment: ""), text: $pluginName)
                            .font(Theme.mono(11)).textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("plugin.scaffold.description", comment: "Description"))
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        TextField(NSLocalizedString("plugin.scaffold.description.placeholder", comment: ""), text: $pluginDescription)
                            .font(Theme.mono(11)).textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    }

                    // Author
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("plugin.scaffold.author", comment: "Author"))
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        TextField(NSLocalizedString("plugin.scaffold.author.placeholder", comment: ""), text: $pluginAuthor)
                            .font(Theme.mono(11)).textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    }

                    // Feature toggles
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("plugin.scaffold.features", comment: "Features"))
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                            featureToggle("Hooks", icon: "gearshape.2", isOn: $includeHooks)
                            featureToggle("Slash Commands", icon: "command", isOn: $includeSlashCommands)
                            featureToggle("Characters", icon: "person.2.fill", isOn: $includeCharacters)
                            featureToggle("Panel (HTML)", icon: "rectangle.on.rectangle", isOn: $includePanel)
                            featureToggle("Themes", icon: "paintpalette.fill", isOn: $includeThemes)
                            featureToggle("Effects", icon: "sparkles", isOn: $includeEffects)
                            featureToggle("Furniture", icon: "sofa.fill", isOn: $includeFurniture)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Footer
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text(NSLocalizedString("cancel", comment: ""))
                        .font(Theme.mono(10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                }.buttonStyle(.plain)

                Button(action: {
                    var opts = PluginManager.ScaffoldOptions(
                        includeHooks: includeHooks,
                        includeSlashCommands: includeSlashCommands,
                        includeCharacters: includeCharacters,
                        includeSettings: true,
                        includePanel: includePanel,
                        includeThemes: includeThemes,
                        includeEffects: includeEffects,
                        includeFurniture: includeFurniture
                    )
                    opts.pluginDescription = pluginDescription
                    opts.pluginAuthor = pluginAuthor
                    onScaffold(pluginName, opts)
                }) {
                    Text(NSLocalizedString("plugin.scaffold.btn", comment: ""))
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(
                            pluginName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textDim : Theme.green
                        ))
                }
                .buttonStyle(.plain)
                .disabled(pluginName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480, height: 580)
        .background(Theme.bg)
        .onChange(of: selectedTemplate) { _, template in
            let opts = template.scaffoldOptions
            includeHooks = opts.includeHooks
            includeSlashCommands = opts.includeSlashCommands
            includeCharacters = opts.includeCharacters
            includePanel = opts.includePanel
            includeThemes = opts.includeThemes
            includeEffects = opts.includeEffects
            includeFurniture = opts.includeFurniture
        }
    }

    private func templateCard(_ template: PluginTemplate) -> some View {
        let isSelected = selectedTemplate == template
        let tintColor: Color = {
            switch template.tint {
            case "purple": return Theme.purple
            case "cyan": return Theme.cyan
            case "orange": return Theme.orange
            default: return Theme.green
            }
        }()

        return Button(action: { selectedTemplate = template }) {
            VStack(spacing: 6) {
                Image(systemName: template.icon)
                    .font(.system(size: Theme.iconSize(16), weight: .bold))
                    .foregroundColor(isSelected ? tintColor : Theme.textDim)
                Text(template.label)
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                Text(template.description)
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? tintColor.opacity(0.08) : Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                isSelected ? tintColor.opacity(0.4) : Theme.border.opacity(0.3), lineWidth: isSelected ? 1.5 : 1
            ))
        }.buttonStyle(.plain)
    }

    private func featureToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(9), weight: .medium))
                    .foregroundColor(isOn.wrappedValue ? Theme.accent : Theme.textDim)
                    .frame(width: 14)
                Text(label)
                    .font(Theme.mono(9))
                    .foregroundColor(isOn.wrappedValue ? Theme.textPrimary : Theme.textDim)
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundColor(isOn.wrappedValue ? Theme.green : Theme.textDim)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(isOn.wrappedValue ? Theme.green.opacity(0.05) : .clear))
        }.buttonStyle(.plain)
    }
}
