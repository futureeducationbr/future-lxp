let str = React.string

open CoursesCurriculum__Types

let t = I18n.t(~scope="components.CoursesCurriculum__Discuss")

let linkToCommunity = (communityId, targetId) =>
  "/communities/" ++ (communityId ++ ("?target_id=" ++ targetId))

let linkToNewPost = (communityId, targetId) =>
  "/communities/" ++ (communityId ++ ("/new_topic" ++ ("?target_id=" ++ targetId)))

let topicCard = topic => {
  let topicId = topic |> Community.topicId
  let topicLink = "/topics/" ++ topicId
  <div
    href=topicLink
    key=topicId
    className="flex justify-between items-center px-5 py-4 bg-white border-t">
    <span className="text-sm font-semibold"> {topic |> Community.topicTitle |> str} </span>
    <a href=topicLink className="btn btn-primary-ghost btn-small"> {"Ver" |> str} </a>
  </div>
}

let handleEmpty = () =>
  <div className="flex flex-col justify-center items-center bg-white px-3 py-10">
    <i className="fa fa-comments text-5xl text-gray-600 mb-2 " />
    <div className="text-center">
      <h4 className="font-bold">
        {t("description_no_discuss") |> str}
      </h4>
      <p> {t("description_sub_discuss") |> str} </p>
    </div>
  </div>

let actionButtons = (community, targetId) => {
  let communityId = community |> Community.id
  let communityName = community |> Community.name

  <div className="flex">
    <a
      title={"Ver todos os tópicos desta aula na comunidade " ++ (communityName ++ " ")}
      href={linkToCommunity(communityId, targetId)}
      className="btn btn-default mr-3">
       {"Ir para comunidade" |> str}
    </a>
    <a
      title={"Criar um tópico na comunidade " ++ (communityName ++ " ")}
      href={linkToNewPost(communityId, targetId)}
      className="btn btn-primary">
      {t("create_new_topic") |> str}
    </a>
  </div>
}

let communityTitle = community =>
  <h5 className="font-bold">
    {"Topicos da comunidade de " ++ ((community |> Community.name)) |> str}
  </h5>

@react.component
let make = (~targetId, ~communities) =>
  <div className=""> {communities |> Js.Array.map(community => {
      let communityId = community |> Community.id
      <div key=communityId className="mt-12 bg-gray-100 px-6 py-4 rounded-lg">
        <div className="flex flex-col md:flex-row w-full justify-between pb-3 items-center">
          <div> {communityTitle(community)} </div> {actionButtons(community, targetId)}
        </div>
        <div className="justify-between rounded-lg overflow-hidden shadow">
          {switch community |> Community.topics {
          | [] => handleEmpty()
          | topics => topics |> Array.map(topic => topicCard(topic)) |> React.array
          }}
        </div>
      </div>
    }) |> React.array} </div>
