// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI
import MessengerAPI

nonisolated public struct GetUserQuery: GraphQLQuery {
  public static let operationName: String = "GetUser"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query GetUser($userId: UUID!) { getUser(user_id: $userId) { __typename user_id nick_name } }"#
    ))

  public var userId: MessengerAPI.UUID

  public init(userId: MessengerAPI.UUID) {
    self.userId = userId
  }

  @_spi(Unsafe) public var __variables: Variables? { ["userId": userId] }

  nonisolated public struct Data: MessengerAPI.SelectionSet {
    @_spi(Unsafe) public let __data: DataDict
    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { MessengerAPI.Objects.Query }
    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
      .field("getUser", GetUser.self, arguments: ["user_id": .variable("userId")]),
    ] }
    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
      GetUserQuery.Data.self
    ] }

    public var getUser: GetUser { __data["getUser"] }

    /// GetUser
    ///
    /// Parent Type: `User`
    nonisolated public struct GetUser: MessengerAPI.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { MessengerAPI.Objects.User }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("user_id", MessengerAPI.UUID.self),
        .field("nick_name", String.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        GetUserQuery.Data.GetUser.self
      ] }

      public var user_id: MessengerAPI.UUID { __data["user_id"] }
      public var nick_name: String { __data["nick_name"] }
    }
  }
}
