// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import Alamofire
import ArgumentParser
import Foundation
import JSON
//import SwiftPackageList
//import SwiftPackageListCore

extension JSON: @unchecked @retroactive Sendable {}

extension Optional {
    enum Error: Swift.Error {
        case missingValue
    }
    func unwrapped() throws -> Wrapped {
        guard let value = self else {
            throw Error.missingValue
        }
        return value
    }
}

struct Output: Codable {
    let repos: [Repo]
    let updatable: [Repo]
}

struct Repo: Codable, SafeJSONRepresentable {
    var json: JSON {
        return JSON(
            dictionaryLiteral: ("currentVersion", currentVersion),
            ("name", name),
            ("repositoryURL", repositoryURL),
            ("lastUpdate", lastUpdate ?? ""),
            ("latestVersion", latestVersion ?? ""),
            ("isUpToDate", isUpToDate)
        )
    }

    let currentVersion: String
    let name: String
    let repositoryURL: String

    var lastUpdate: String?
    var latestVersion: String?

    var isUpToDate: Bool { currentVersion == latestVersion }

    func updated(latestVersion: String?, publishedAt: String?) -> Repo {
        Repo(
            currentVersion: currentVersion,
            name: name,
            repositoryURL: repositoryURL,
            lastUpdate: publishedAt,
            latestVersion: latestVersion)
    }
}

@main
struct SPMUpToDate: AsyncParsableCommand {
    @Argument(help: "optional path for a Swift-package-list generated file") var packageListPath:
        String?

    mutating func run() async throws {
        var repos = [Repo]()
        if let packageListPath {
            let packageListURL = URL(fileURLWithPath: packageListPath)

            let packageListJSON = try JSONDecoder().decode(
                JSON.self, from: Data(contentsOf: packageListURL))
            //            print(packageListJSON.array?.first?.version)
            //.filter({ $0.name == "OTPublishersHeadlessSDK" })
            for package in packageListJSON.array ?? [JSON]() {
                repos.append(
                    try Repo(
                        currentVersion: package.version.string.unwrapped(),
                        name: package.name.string.unwrapped(),
                        repositoryURL: package.repositoryURL.string.unwrapped())
                )
            }
        }

        print("Checking repository updates...")
        var updatedRepos: [Repo] = []
        for repo in repos {
            try await updatedRepos.append(testGithubAPIFetch(repo))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        var output = Output(
            repos: updatedRepos,
            updatable: updatedRepos.filter({ $0.currentVersion != $0.latestVersion }).map(\.self)

        )
        let data = try encoder.encode(output)
        print(String(data: data, encoding: .utf8)!)
        let outputURL = URL(fileURLWithPath: "output.json")
        try data.write(to: outputURL)

    }

    func testGithubAPIFetch(_ repo: Repo) async throws -> Repo {
        let repoTag = repo.repositoryURL.replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")

        print("https://api.github.com/repos/\(repoTag)/releases")
        let data: JSON = try await AF.request(
            "https://api.github.com/repos/\(repoTag)/releases",
            headers: [
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            ]
        )
        .serializingDecodable(JSON.self)
        .response
        .value
        .unwrapped()

        if data.array?.isEmpty != .some(false) {
            print("https://api.github.com/repos/\(repoTag)/tags")

            let data: JSON = try await AF.request(
                "https://api.github.com/repos/\(repoTag)/tags",
                headers: [
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                ]
            )
            .serializingDecodable(JSON.self)
            .response
            .value
            .unwrapped()
            //print(data)
            if let d = data.array?.first {
                if let url = d.commit.url.string,
                    let name = d.name.string
                {

                    let data: JSON = try await AF.request(
                        url,
                        headers: [
                            "Accept": "application/vnd.github+json",
                            "X-GitHub-Api-Version": "2022-11-28",
                        ]
                    )
                    .serializingDecodable(JSON.self)
                    .response
                    .value
                    .unwrapped()

//                    print("updated", repo.repositoryURL, name.replacingOccurrences(of: "v", with: ""), data.commit.author.date)
                    return repo.updated(
                        latestVersion: name.replacingOccurrences(of: "v", with: ""),
                        publishedAt: data.commit.author.date.string)
                } else {
                    print(d)
                }
            }
        } else {
            if let tag = data.array?.first?.tag_name.string,
                let publishedAt = data.array?.first?.published_at.string
            {
//                print("updated", repo.repositoryURL, tag.replacingOccurrences(of: "v", with: ""), publishedAt)
                return repo.updated(latestVersion: tag.replacingOccurrences(of: "v", with: ""), publishedAt: publishedAt)
            } else {
                print("\(repo.name) no releases")
            }
        }

        print("Failed to update... \(repo.repositoryURL)")
        return repo
    }

}
