import SwiftUI

struct HubRootView: View {
    @ObservedObject var hub: HubController
    @ObservedObject var store: TaskStore

    var body: some View {
        let open = hub.isOpen
        let flare = open ? HubController.openTopRadius : HubController.closedTopRadius
        let base = open ? hub.openSize : hub.collapsedSize
        // Recolhido, o notch "incha" um pouco conforme o mouse se aproxima.
        let bulge = open ? 0 : hub.proximity
        let size = CGSize(width: base.width + bulge * 16, height: base.height + bulge * 5)

        ZStack(alignment: .top) {
            NotchShape(topRadius: flare, bottomRadius: open ? 30 : 10 + bulge * 3)
                .fill(Color.black)
                .shadow(color: .black.opacity(open ? 0.45 : 0), radius: open ? 18 : 0, y: open ? 8 : 0)

            if open {
                ExpandedView(hub: hub, store: store)
                    .padding(.horizontal, flare)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                            .animation(.easeIn(duration: 0.12))
                    ))
            } else {
                // Recolhido: só o contorno, com o progresso de hoje.
                ProgressOutline(
                    shape: ProgressU(side: flare + 1, bottom: 1, radius: 9 + bulge * 3),
                    fraction: .fraction(store.progress(on: hub.today)),
                    lineWidth: 2 + bulge * 0.5
                )
                .opacity(0.8 + bulge * 0.2)
                .transition(.opacity.animation(.easeOut(duration: 0.25).delay(0.12)))
            }
        }
        .frame(width: size.width + flare * 2, height: size.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

struct ExpandedView: View {
    @ObservedObject var hub: HubController
    @ObservedObject var store: TaskStore

    @State private var appeared = false

    private struct DayProgress: Equatable {
        var day: String
        var done: Int
        var total: Int
    }

    var body: some View {
        let day = hub.selectedDay
        let progress = store.progress(on: day)
        let fraction = Double.fraction(progress)

        ZStack {
            // A linha em U se desenha ao abrir e depois acompanha o progresso.
            ProgressOutline(
                shape: ProgressU(top: 4, side: 12, bottom: 12, radius: 20),
                fraction: appeared ? fraction : 0,
                lineWidth: 3,
                glow: hub.glow
            )
            .animation(Motion.fill.delay(appeared ? 0 : 0.1), value: fraction)
            .animation(Motion.fill.delay(0.15), value: appeared)

            VStack(spacing: 0) {
                TopBar(hub: hub, progress: progress)
                    .frame(height: hub.notch.height)
                    .reveal(appeared, delay: 0.03, offset: -6, blur: 3)

                HStack(alignment: .top, spacing: 14) {
                    TasksCard(hub: hub, store: store, appeared: appeared)
                        .frame(maxWidth: .infinity)
                        .reveal(appeared, delay: 0.06)
                    StreakCard(
                        days: hub.recentDays,
                        levels: hub.recentDays.map(store.level(on:)),
                        today: hub.today,
                        selected: hub.selectedDay,
                        streak: store.streak(today: hub.today),
                        appeared: appeared,
                        onSelect: { day in withAnimation(Motion.nav) { hub.select(day) } }
                    )
                    .frame(width: 250)
                    .reveal(appeared, delay: 0.1)
                }
                .padding(.horizontal, 26)
                .padding(.top, 8)
                .padding(.bottom, 26)
            }
        }
        .foregroundStyle(.white)
        .onAppear { appeared = true }
        .onChange(of: DayProgress(day: day, done: progress.done, total: progress.total)) { old, new in
            // Brilho + haptic quando o dia fica completo (não ao só trocar de dia).
            guard old.day == new.day, new.total > 0, new.done == new.total, old.done < new.done else { return }
            hub.glow += 1
            Haptics.success()
        }
    }
}

private struct TopBar: View {
    @ObservedObject var hub: HubController
    var progress: (done: Int, total: Int)

    var body: some View {
        let day = hub.selectedDay
        let edge: Edge = hub.navDirection > 0 ? .trailing : .leading

        HStack(spacing: 6) {
            navButton("chevron.left") { go(Day.offset(day, by: -1)) }

            Button { go(hub.today) } label: {
                // Largura fixa + corte: a data antiga sai deslizando sem invadir a barra de menus.
                ZStack(alignment: .leading) {
                    Text(Day.label(day))
                        .font(.system(size: 13, weight: .semibold))
                        .fixedSize()
                        .id(day)
                        .transition(.push(from: edge))
                }
                .frame(width: 92, height: 22, alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .help("Voltar para hoje")

            if let rel = Day.relative(day, today: hub.today) {
                Text(rel)
                    .font(.system(size: 9.5, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .foregroundStyle(day == hub.today ? Theme.blue : Theme.muted)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(day == hub.today ? Theme.blue.opacity(0.18) : Color(white: 0.15))
                    )
                    .id(rel)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            navButton("chevron.right") { go(Day.offset(day, by: 1)) }

            Spacer()

            HStack(spacing: 0) {
                Text("\(progress.done)")
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.numericText(value: Double(progress.done)))
                Text(" / ")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                Text("\(progress.total)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText(value: Double(progress.total)))
                Text(" feitas")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            .animation(Motion.snappy, value: progress.done)
            .animation(Motion.snappy, value: progress.total)

            OptionsMenu()
        }
        .monospacedDigit()
        .padding(.horizontal, 26)
    }

    private func go(_ day: String) {
        withAnimation(Motion.nav) { hub.select(day) }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        NavArrow(symbol: symbol, action: action)
    }
}

private struct NavArrow: View {
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: hovering ? 0.14 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(hovering ? Color.white : Theme.muted)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// Menu "⋯" no canto do hub: início automático, dados e sair.
private struct OptionsMenu: View {
    @State private var opensAtLogin = AppActions.opensAtLogin
    @State private var hovering = false

    var body: some View {
        Menu {
            Button {
                AppActions.toggleOpenAtLogin()
                opensAtLogin = AppActions.opensAtLogin
            } label: {
                if opensAtLogin {
                    Label("Abrir ao iniciar sessão", systemImage: "checkmark")
                } else {
                    Text("Abrir ao iniciar sessão")
                }
            }
            Button("Mostrar dados no Finder") { AppActions.revealData() }
            Divider()
            Button("Sair do Goals") { AppActions.quit() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: hovering ? 0.14 : 0)))
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(hovering ? Color.white : Theme.muted)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help("Opções")
        .onAppear { opensAtLogin = AppActions.opensAtLogin }
    }
}
