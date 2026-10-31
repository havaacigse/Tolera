import PhotosUI
import SwiftUI

/// İçindekiler fotoğrafından kontrol ekranı: fotoğraf seç/çek → okunan metni
/// düzenle → "Kontrol et" ile analiz et. Kategori bilgisi olmadığından
/// alternatif önerisi bölümü burada hiç gösterilmez.
struct IngredientsScanView: View {
    @State private var viewModel: IngredientsScanViewModel
    @State private var isShowingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?

    init(viewModel: IngredientsScanViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourceButtons

                if viewModel.isRecognizing {
                    ProgressView("Metin okunuyor…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else if let error = viewModel.recognitionError {
                    Text(error)
                        .foregroundStyle(.red)
                } else if viewModel.result != nil {
                    resultSection
                } else if !viewModel.fullRecognizedText.isEmpty {
                    reviewSection
                }

                #if DEBUG
                debugSection
                #endif
            }
            .padding()
        }
        .navigationTitle("İçindekileri Fotoğrafla")
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView(
                onCapture: { data in
                    isShowingCamera = false
                    viewModel.recognizeText(from: data)
                },
                onCancel: { isShowingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.recognizeText(from: data)
                }
                photoPickerItem = nil
            }
        }
    }

    private var sourceButtons: some View {
        HStack(spacing: 12) {
            if CameraCaptureView.isAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Fotoğraf Çek", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label("Fotoğraf Seç", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Okunan metni kontrol et ve gerekirse düzelt")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if !viewModel.hasIngredientsHeading {
                Text("⚠️ 'İçindekiler' başlığı bulunamadı. Ambalajın 'İçindekiler' yazan bölümünü yakından çekmeyi dene, yoksa sonuç güvenilir olmayabilir.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            TextEditor(text: viewModel.isShowingFullText ? $viewModel.fullRecognizedText : $viewModel.extractedText)
                .frame(minHeight: 160)
                .padding(4)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(viewModel.isShowingFullText ? "Ayıklanmış metni göster" : "Tüm metni göster") {
                viewModel.isShowingFullText.toggle()
            }
            .font(.footnote)

            Button("Kontrol et") {
                viewModel.checkText()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = viewModel.result {
            VStack(alignment: .leading, spacing: 16) {
                Text("Kaynak: ambalaj fotoğrafı (cihazda okundu)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ProductResultView(result: result)

                Button("Başka Bir Fotoğraf") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Dil düzeltmesi", isOn: $viewModel.isLanguageCorrectionEnabled)
                .font(.footnote)

            Text("OCR dili: \(viewModel.debugSelectedLanguage) (gerçek cihazda farklı olabilir)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
    #endif
}

#Preview {
    NavigationStack {
        IngredientsScanView(
            viewModel: IngredientsScanViewModel(
                textRecognitionService: VisionTextRecognitionService(),
                profileRepository: UserProfileRepositoryImpl()
            )
        )
    }
}
