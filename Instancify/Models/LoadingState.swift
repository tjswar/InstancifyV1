enum LoadingState {
    case none
    case loading(String)
    case progress(String, Double)
    
    var message: String {
        switch self {
        case .none: return ""
        case .loading(let msg): return msg
        case .progress(let msg, _): return msg
        }
    }
    
    var isLoading: Bool {
        switch self {
        case .none: return false
        default: return true
        }
    }
} 