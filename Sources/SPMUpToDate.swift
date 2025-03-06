// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import Alamofire
import ArgumentParser
import Foundation
import JSON

extension JSON: @unchecked @retroactive Sendable {}

extension Optional {
    enum Error: Swift.Error {
        case missingValue(UInt)
    }

    func unwrapped(line: UInt = #line) throws -> Wrapped {
        guard let value = self else {
            throw Error.missingValue(line)
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
    @Argument(
        help:
            "optional path for a Swift-package-list generated file, defaults to `package-list.json`"
    ) var packageListPath: String = "package-list.json"

    @Flag(help: "updatable-only: only show repos that have an update") var updatableOnly: Bool =
        false

    mutating func run() async throws {
        var repos = [Repo]()

        let packageListURL = URL(fileURLWithPath: packageListPath)

        let packageListJSON = try JSONDecoder().decode(
            JSON.self, from: Data(contentsOf: packageListURL))

        for package in packageListJSON.array ?? [JSON]() {
            do {
                repos.append(
                    try Repo(
                        currentVersion: package.version.string.unwrapped(),
                        name: package.name.string.unwrapped(),
                        repositoryURL: (package.repositoryURL.string ?? package.location.string).unwrapped())
                )
            } catch {
                print(error)
                print(package)
                print("failed: \(package.version.string ?? "No Version")")
            }
        }

        print("Checking repository updates...")
        var updatedRepos: [Repo] = []
        for repo in repos {
            try await updatedRepos.append(testGithubAPIFetch(repo))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let output: Output
        if updatableOnly {
            output = Output(
                repos: [],
                updatable: updatedRepos.filter({ $0.currentVersion != $0.latestVersion }).map(
                    \.self))

        } else {
            output = Output(
                repos: updatedRepos,
                updatable: updatedRepos.filter({ $0.currentVersion != $0.latestVersion }).map(
                    \.self))
        }

        let data = try encoder.encode(output)
        print(String(data: data, encoding: .utf8)!)
        let outputURL = URL(fileURLWithPath: "updatablePackages.json")
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

            // print(data)
//            if repoTag == "google/interop-ios-for-google-sdks" {
//                print(data)
//            }
            
            if let d = data.array?.first(where: { tag in
                
                if tag.name.string?.contains("CocoaPods") == .some(true) {
                    return false
                } else {
                    return true
                }
            }) {
//            if let d = data.array?.first {
                
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

                    print(
                        "updated", repo.repositoryURL, name.replacingOccurrences(of: "v", with: ""),
                        data.commit.author.date)
                    return repo.updated(
                        latestVersion: name.replacingOccurrences(of: "v", with: ""),
                        publishedAt: data.commit.author.date.string)
                } else {
                    print(d)
                }
            }
        } else {
            // print(data)
            if let release = data.array?.first(where: { tag in
                if let tagName = tag.tag_name.string {
                    if tagName.contains("CocoaPods") {
                        return false
                    } else {
                        return true
                    }
                } else {
                    return false
                }

            }),
                let tag = release.tag_name.string,
                let publishedAt = release.published_at.string
            {
                //                print("updated", repo.repositoryURL, tag.replacingOccurrences(of: "v", with: ""), publishedAt)
                return repo.updated(
                    latestVersion: tag.replacingOccurrences(of: "v", with: ""),
                    publishedAt: publishedAt)
            } else {
                print("\(repo.name) no releases")
            }
        }

        print("Failed to update... \(repo.repositoryURL)")
        return repo
    }

}
