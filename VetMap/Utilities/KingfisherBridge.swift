import SwiftUI

#if canImport(Kingfisher)
import Kingfisher

typealias VetMapKFImage = KFImage
#else
typealias VetMapKFImage = EmptyView
#endif
