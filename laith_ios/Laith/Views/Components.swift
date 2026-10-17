import SwiftUI
import PhotosUI

struct CardBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primaryBlue.opacity(0.08), radius: 8, y: 3)
    }
}

struct PrimaryButton: View {
    let title: String
    var color: Color = .primaryBlue
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(disabled ? Color.cardBorder : color).foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }.disabled(disabled)
    }
}

struct BureauBanner: View {
    var body: some View {
        Text("👑 Mode Bureau actif : boutons ✏ de modification visibles")
            .font(.caption.bold()).foregroundColor(Color(hex: 0x78350F))
            .padding(8).frame(maxWidth: .infinity).background(Color(hex: 0xFFFBEB))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct Base64Image: View {
    let b64: String?
    var fallback = "person.fill"
    var body: some View {
        if let img = ImageUtil.decode(b64) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack { Color.daySelected; Image(systemName: fallback).foregroundColor(.primaryBlue) }
        }
    }
}

struct AvatarView: View {
    let b64: String?
    let initials: String
    var size: CGFloat = 44
    var body: some View {
        Group {
            if let img = ImageUtil.decode(b64) { Image(uiImage: img).resizable().scaledToFill() }
            else {
                ZStack { Color.primaryBlue; Text(initials.isEmpty ? "?" : initials).foregroundColor(.white).font(.system(size: size * 0.38, weight: .bold)) }
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}

/// Sélecteur de photo (galerie) → image réduite en Base64.
struct PhotoPickerButton<Label: View>: View {
    var maxSide: CGFloat = 600
    let onPicked: (String) -> Void
    @ViewBuilder var label: Label
    @State private var item: PhotosPickerItem?
    var body: some View {
        PhotosPicker(selection: $item, matching: .images) { label }
            .onChange(of: item) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data), let b64 = ImageUtil.encode(ui, maxSide: maxSide) {
                        onPicked(b64)
                    }
                    item = nil
                }
            }
    }
}

struct FormField: View {
    let label: String
    @Binding var text: String
    var multiline = false
    var disabled = false
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.bold()).foregroundColor(.textBlue)
            Group {
                if multiline { TextField("", text: $text, axis: .vertical).lineLimit(3...8) }
                else { TextField("", text: $text).keyboardType(keyboard) }
            }
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .padding(10).background(Color.white).disabled(disabled).opacity(disabled ? 0.7 : 1)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cardBorder))
        }
    }
}

struct ErrorMessage: Identifiable { let id = UUID(); let title: String; let body: String }

/// Logo officiel du club (repris de l'application Android).
struct ClubLogo: View {
    var size: CGFloat = 88
    var body: some View {
        Image("Logo").resizable().scaledToFill().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .overlay(RoundedRectangle(cornerRadius: size * 0.22).stroke(Color.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .accessibilityLabel("Logo FEEL ISSIK")
    }
}

/// Bandeau d'état vide / chargement, cohérent sur tous les écrans.
struct EmptyState: View {
    let icon: String, text: String
    var body: some View {
        VStack(spacing: 8) {
            Text(icon).font(.system(size: 36))
            Text(text).font(.callout).foregroundColor(.textGray).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(28)
    }
}


/// Pastilles qui passent à la ligne automatiquement (équivalent du ChipGroup Android).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
