import SwiftUI

struct LoginPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)
            VStack(alignment: .leading, spacing: 20) {
                header
                fields
                actions
            }
            .frame(width: 360)
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI AutoDev")
                        .font(.title3.weight(.semibold))
                    Text("登录后进入工作台")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("测试账号：admin  密码：admin2026")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("账号")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                TextField("请输入账号", text: Binding(
                    get: { viewModel.state.loginUsername },
                    set: { viewModel.updateLoginUsername($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isChecking)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("密码")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                SecureField("请输入密码", text: Binding(
                    get: { viewModel.state.loginPassword },
                    set: { viewModel.updateLoginPassword($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isChecking)
                .onSubmit { viewModel.signIn() }
            }

            if !viewModel.state.loginError.isEmpty {
                Text(viewModel.state.loginError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        Button {
            viewModel.signIn()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                }
                Text(viewModel.isChecking ? "登录中" : "登录")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isChecking)
        .keyboardShortcut(.defaultAction)
    }
}

#if DEBUG
struct LoginPage_Previews: PreviewProvider {
    static var previews: some View {
        LoginPage(viewModel: .preview())
            .frame(width: 900, height: 620)
    }
}
#endif
