import Foundation

struct DeviceFilterMenuSnapshot {
    struct StatusItem {
        let filter: DeviceStatusFilter
        let title: String
        let systemImage: String
    }

    struct CategoryItem {
        let category: Device.Category
        let title: String
        let systemImage: String
    }

    struct VendorItem {
        let vendor: String
        let title: String
    }

    struct NetworkRoleItem {
        let type: DeviceType
        let title: String
        let systemImage: String
    }

    let statuses: [StatusItem]
    let categories: [CategoryItem]
    let vendors: [VendorItem]
    let roles: [NetworkRoleItem]

    static let empty = DeviceFilterMenuSnapshot(statuses: [], categories: [], vendors: [], roles: [])

    static func make(viewModel: DeviceListViewModel, store: AppStore) -> DeviceFilterMenuSnapshot {
        let statuses = DeviceStatusFilter.allCases.compactMap { filter -> StatusItem? in
            let count = viewModel.statusCount(for: filter, store: store)
            guard filter == .all || filter == viewModel.statusFilter || count > 0 else { return nil }
            let title = filter == .all ? "All (\(count))" : "\(filter.rawValue) (\(count))"
            return StatusItem(filter: filter, title: title, systemImage: filter.systemImage)
        }

        let categories = Device.Category.allCases.compactMap { category -> CategoryItem? in
            let count = viewModel.typeCount(for: category, store: store)
            guard category == viewModel.categoryFilter || count > 0 else { return nil }
            return CategoryItem(
                category: category,
                title: "\(category.label) (\(count))",
                systemImage: category.systemImage
            )
        }

        let vendors = Array(Set(store.devices.compactMap { $0.definition?.vendor })).sorted().compactMap { vendor -> VendorItem? in
            let count = viewModel.vendorCount(for: vendor, store: store)
            guard vendor == viewModel.vendorFilter || count > 0 else { return nil }
            return VendorItem(vendor: vendor, title: "\(vendor) (\(count))")
        }

        let relevantRoleTypes: [DeviceType] = [.router, .endDevice]
        let roles = relevantRoleTypes.compactMap { type -> NetworkRoleItem? in
            let count = viewModel.roleCount(for: type, store: store)
            guard type == viewModel.typeFilter || count > 0 else { return nil }
            let title: String
            let systemImage: String
            switch type {
            case .router:
                title = "Routers (\(count))"
                systemImage = "point.3.connected.trianglepath.dotted"
            case .endDevice:
                title = "End Devices (\(count))"
                systemImage = "leaf"
            default:
                return nil
            }
            return NetworkRoleItem(type: type, title: title, systemImage: systemImage)
        }

        return DeviceFilterMenuSnapshot(statuses: statuses, categories: categories, vendors: vendors, roles: roles)
    }
}
