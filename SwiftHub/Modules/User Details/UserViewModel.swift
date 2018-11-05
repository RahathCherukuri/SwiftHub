//
//  UserViewModel.swift
//  SwiftHub
//
//  Created by Sygnoos9 on 7/8/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift

class UserViewModel: ViewModel, ViewModelType {

    struct Input {
        let headerRefresh: Observable<Void>
        let imageSelection: Observable<Void>
        let openInWebSelection: Observable<Void>
        let repositoriesSelection: Observable<Void>
        let followersSelection: Observable<Void>
        let followingSelection: Observable<Void>
        let selection: Driver<UserSectionItem>
    }

    struct Output {
        let items: Observable<[UserSection]>
        let username: Driver<String>
        let fullname: Driver<String>
        let description: Driver<String>
        let imageUrl: Driver<URL?>
        let repositoriesCount: Driver<Int>
        let followersCount: Driver<Int>
        let followingCount: Driver<Int>
        let imageSelected: Driver<Void>
        let openInWebSelected: Driver<URL?>
        let repositoriesSelected: Driver<RepositoriesViewModel>
        let usersSelected: Driver<UsersViewModel>
        let selectedEvent: Driver<UserSectionItem>
    }

    let user: BehaviorRelay<User?>

    init(user: User?, provider: SwiftHubAPI) {
        self.user = BehaviorRelay(value: user)
        super.init(provider: provider)
    }

    func transform(input: Input) -> Output {
        input.headerRefresh.flatMapLatest { () -> Observable<User> in
            let request: Observable<User>
            if let user = self.user.value, !user.isMine() {
                let owner = user.login ?? ""
                switch user.type {
                case .user: request = self.provider.user(owner: owner)
                case .organization: request = self.provider.organization(owner: owner)
                }
            } else {
                request = self.provider.profile()
            }
            return request
                .trackActivity(self.loading)
                .trackActivity(self.headerLoading)
                .trackError(self.error)
            }.subscribe(onNext: { (user) in
                self.user.accept(user)
            }).disposed(by: rx.disposeBag)

        let username = user.map { $0?.login ?? "" }.asDriverOnErrorJustComplete()
        let fullname = user.map { $0?.name ?? "" }.asDriverOnErrorJustComplete()
        let description = user.map { $0?.descriptionField ?? "" }.asDriverOnErrorJustComplete()
        let imageUrl = user.map { $0?.avatarUrl?.url }.asDriverOnErrorJustComplete()
        let repositoriesCount = user.map { $0?.publicRepos ?? 0 }.asDriverOnErrorJustComplete()
        let followersCount = user.map { $0?.followers ?? 0 }.asDriverOnErrorJustComplete()
        let followingCount = user.map { $0?.following ?? 0 }.asDriverOnErrorJustComplete()
        let imageSelected = input.imageSelection.asDriverOnErrorJustComplete()
        let openInWebSelected = input.openInWebSelection.map { () -> URL? in
            self.user.value?.htmlUrl?.url
        }.asDriver(onErrorJustReturn: nil)

        let repositoriesSelected = input.repositoriesSelection.asDriver(onErrorJustReturn: ())
            .map { () -> RepositoriesViewModel in
                let mode = RepositoriesMode.userRepositories(user: self.user.value ?? User())
                let viewModel = RepositoriesViewModel(mode: mode, provider: self.provider)
                return viewModel
        }

        let followersSelected = input.followersSelection.map { UsersMode.followers(user: self.user.value ?? User()) }
        let followingSelected = input.followingSelection.map { UsersMode.following(user: self.user.value ?? User()) }

        let usersSelected = Observable.of(followersSelected, followingSelected).merge()
            .asDriver(onErrorJustReturn: .followers(user: User()))
            .map { (mode) -> UsersViewModel in
                let viewModel = UsersViewModel(mode: mode, provider: self.provider)
                return viewModel
        }

        let items = user.map { (user) -> [UserSection] in
            var items: [UserSectionItem] = []

            // Events
            let eventsCellViewModel = UserDetailCellViewModel(with: R.string.localizable.userEventsCellTitle.key.localized(),
                                                              detail: "",
                                                              image: R.image.icon_cell_events(),
                                                              hidesDisclosure: false)
            items.append(UserSectionItem.eventsItem(viewModel: eventsCellViewModel))

            if let company = user?.company {
                let companyCellViewModel = UserDetailCellViewModel(with: R.string.localizable.userCompanyCellTitle.key.localized(),
                                                                   detail: company,
                                                                   image: R.image.icon_cell_company(),
                                                                   hidesDisclosure: false)
                items.append(UserSectionItem.companyItem(viewModel: companyCellViewModel))
            }

            if let blog = user?.blog, blog.isNotEmpty {
                let companyCellViewModel = UserDetailCellViewModel(with: R.string.localizable.userBlogCellTitle.key.localized(),
                                                                   detail: blog,
                                                                   image: R.image.icon_cell_link(),
                                                                   hidesDisclosure: false)
                items.append(UserSectionItem.blogItem(viewModel: companyCellViewModel))
            }

            return [
                UserSection.user(title: "", items: items)
            ]
        }

        let selectedEvent = input.selection

        return Output(items: items,
                      username: username,
                      fullname: fullname,
                      description: description,
                      imageUrl: imageUrl,
                      repositoriesCount: repositoriesCount,
                      followersCount: followersCount,
                      followingCount: followingCount,
                      imageSelected: imageSelected,
                      openInWebSelected: openInWebSelected,
                      repositoriesSelected: repositoriesSelected,
                      usersSelected: usersSelected,
                      selectedEvent: selectedEvent)
    }

    func viewModel(for item: UserSectionItem) -> ViewModel? {
        switch item {
        case .eventsItem:
            if let user = self.user.value {
                let viewModel = EventsViewModel(mode: EventsMode.user(user: user), provider: self.provider)
                return viewModel
            }
        case .companyItem:
            if let companyName = self.user.value?.company?.removingPrefix("@") {
                var user = User()
                user.login = companyName
                let viewModel = UserViewModel(user: user, provider: self.provider)
                return viewModel
            }
        case .blogItem: return nil
        }
        return nil
    }
}
