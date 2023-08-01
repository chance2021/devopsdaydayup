# Azure Static Web App
今天介绍另一个可以帮助你在Azure上部署网站的服务:**Azure Static Web App**。 这个服务是用来从代码仓库(Code Repository)里直接部署网站代码到Azure上用的。只要代码仓库里的数据一有变动，那么它就会借助CICD Pipeline（这里主要指的是GitHub或者Azure DevOps)自动部署到Azure上。每一次你Push或Pull Request到指定的Branch里，就会触发CICD构建并发布网站。它主要有这么些特性：
1. 可以部署像HTML,CSS, JavaScript和图片这样的静态资源
2. 可以集成Azure Function来提供后端API。
3. 主要是使用GitHub和Azure DevOps来做代码存储了和CICD构建发布
4. 借用了Azure的全球资源，可以让你的静态资源部署到离你的用户最近的位置
5. 免费SSL证书，并且自动更新
6. 提供自定义域名服务
7. 可以集成用户认证系统，包括Azure Active Directory, GitHub, Twitter(X)
8. 可以自定义Role definition和Role  Assignments
9. 可以开启后端路由规则，全权控制访问路由
10. Azure CLI里也支持相关操作